# 类 1Password 密码保存与同步软件设计方案

## 1. 产品目标与范围

### 1.1 目标
设计一个跨平台（iOS / Android / macOS / Windows / Web 浏览器插件）的“零信任”密码管理软件，核心能力包括：
- 安全保存账号密码、支付卡、身份证件、私密笔记。
- 多设备实时同步（最终一致 + 弱网可用）。
- 强加密与端到端（E2EE）默认开启。
- 自动填充、密码生成、泄露检测与团队共享。

### 1.2 非目标（首期不做）
- 不做通用网盘文件同步。
- 不做企业 IAM / SSO 全量替代（先做对接）。
- 不做链上托管或加密货币钱包托管。

---

## 2. 核心用户场景

1. **个人用户**：注册后创建主密码，导入浏览器密码，手机/电脑自动同步。
2. **家庭用户**：共享保险箱（如“家庭网银”），可分成员权限。
3. **团队用户**：部门保险箱（开发、财务），支持成员管理、审计日志。
4. **高安全用户**：强制硬件密钥 + 生物识别 + 定期密钥轮换。

---

## 3. 系统架构（高层）

```text
[Client Apps]
  iOS / Android / Desktop / Browser Extension
       |  (TLS + Certificate Pinning)
       v
[API Gateway]
  - Auth API
  - Vault API
  - Sync API
  - Share API
  - Audit API
       |
       +--> [Metadata DB: PostgreSQL]
       +--> [Encrypted Blob Store: S3/OSS]
       +--> [Event Bus: Kafka/Pulsar]
       +--> [Search Index(可选, 仅密文标签)]
       +--> [KMS/HSM: 仅服务端密钥与签名用途]
```

### 3.1 零信任原则
- 服务器只保存密文与必要元数据，不可解密用户保险箱内容。
- 解密仅在客户端进行。
- 服务端被攻破时，攻击者无法直接读取明文密码。

### 3.2 多端同步模型
- 每条数据项（Item）带版本号（vector clock 或 lamport timestamp）。
- 客户端本地优先写入（离线可用），后台增量同步。
- 冲突策略：字段级合并 + 用户可视化冲突解决。

---

## 4. 数据模型设计

## 4.1 主要实体
- **User**：用户账号、认证策略、设备列表。
- **Device**：设备公钥、最后在线时间、设备风控状态。
- **Vault**：保险箱（个人 / 家庭 / 团队）。
- **Item**：条目（登录、卡片、证件、Secure Note）。
- **Attachment**：附件（证件图片等，分块加密上传）。
- **ShareGrant**：共享授权记录。
- **AuditLog**：关键安全操作日志（不可篡改）。

### 4.2 Item（示例）
```json
{
  "item_id": "uuid",
  "vault_id": "uuid",
  "type": "login",
  "enc_payload": "base64(ciphertext)",
  "enc_item_key": "base64(encrypted_data_key)",
  "version": 42,
  "updated_at": "2026-02-26T12:00:00Z",
  "updated_by_device": "device_uuid",
  "deleted": false
}
```

说明：
- `enc_payload`：使用 item data key（DEK）加密后的完整内容。
- `enc_item_key`：DEK 被 vault key / recipient key 封装后的结果。

---

## 5. 密码学与安全设计

### 5.1 密钥层级（建议）
1. **Master Password**（用户记忆）
2. **KDF 输出密钥**（Argon2id）
3. **Account Unlock Key**（本地保护）
4. **Vault Key**（每个保险箱一个）
5. **Item Data Key（DEK）**（每条数据一个，AES-GCM/ChaCha20-Poly1305）

### 5.2 推荐算法
- KDF：Argon2id（内存成本可配置）
- 对称加密：AES-256-GCM（移动端可选 XChaCha20-Poly1305）
- 非对称：X25519（密钥交换）+ Ed25519（签名）
- 哈希：SHA-256/512（按协议场景）

### 5.3 安全基线
- 全链路 TLS1.3 + 证书固定（移动端）。
- 本地安全存储：iOS Keychain / Android Keystore / Desktop OS Keyring。
- 自动锁定策略：前后台切换、空闲超时、风控触发。
- 防暴力破解：本地与服务端双重速率限制。
- 2FA：TOTP、Passkey（WebAuthn）、硬件密钥（FIDO2）。

### 5.4 应急与恢复
- **恢复码**：离线打印的一次性恢复码。
- **可信联系人恢复（可选）**：Shamir Secret Sharing 分片。
- **设备吊销**：远程吊销后拒绝同步与解密新数据。

---

## 6. 同步与冲突解决

### 6.1 同步流程（简化）
1. 客户端拉取 `sync_cursor` 之后的变更。
2. 解密可读变更并合并到本地数据库。
3. 上传本地未同步变更（批处理 + 重试 + 幂等 token）。
4. 服务端返回新 cursor。

### 6.2 冲突处理
- 默认 Last-Writer-Wins 仅用于无结构字段。
- 结构化字段（用户名、密码、备注）采用字段级 timestamp 合并。
- 同字段冲突时保留双方快照，让用户选择。

### 6.3 离线策略
- 本地 SQLite / Realm 保存加密数据镜像。
- 网络恢复后自动后台同步。
- 附件使用分块上传（断点续传 + chunk hash 校验）。

---

## 7. 共享与团队权限

### 7.1 共享机制
- 不共享主密钥，只共享目标 `Vault Key` 的加密副本。
- 每个接收者使用其设备公钥封装共享密钥。
- 可撤销：撤销后轮换 Vault Key，旧成员无法解密新数据。

### 7.2 权限模型（RBAC）
- Owner：管理成员、删除保险箱、查看审计。
- Admin：管理条目与成员（受限）。
- Editor：新增/编辑条目。
- Viewer：只读。

### 7.3 审计能力
- 记录：登录、导出、分享、权限变更、恢复操作。
- 审计日志签名链（hash chain）防篡改。

---

## 8. 客户端产品功能模块

1. **自动填充**：浏览器插件 + 移动端系统自动填充框架。
2. **密码生成器**：长度、字符集、可读性、规则模板。
3. **安全仪表盘**：弱密码/复用密码/疑似泄露密码检测。
4. **密钥与会话管理**：已登录设备列表，远程退出。
5. **导入导出**：CSV/1Password/Chrome 导入，导出强提醒。

---

## 9. 后端服务拆分建议

- `auth-service`：注册登录、2FA、passkey、设备认证。
- `vault-service`：保险箱与条目元数据。
- `crypto-gateway`：仅做密文格式校验与策略检查，不解密。
- `sync-service`：游标同步、冲突检测、事件流。
- `share-service`：共享关系与密钥封装分发。
- `audit-service`：审计日志写入与查询。
- `notification-service`：安全告警推送（新设备登录等）。

---

## 10. 数据库与存储选型

- PostgreSQL：用户、设备、权限、游标、审计索引。
- 对象存储（S3/OSS）：加密附件、历史版本快照。
- Redis：短期会话、风控计数器、任务幂等键。
- Kafka/Pulsar：同步事件、审计事件、告警事件。

---

## 11. API 设计示例

### 11.1 登录与设备注册
- `POST /v1/auth/login`
- `POST /v1/devices/register`

### 11.2 保险箱与条目
- `GET /v1/vaults`
- `POST /v1/vaults/{vault_id}/items`
- `PATCH /v1/items/{item_id}`
- `DELETE /v1/items/{item_id}`

### 11.3 同步
- `GET /v1/sync/changes?cursor=...`
- `POST /v1/sync/commit`

### 11.4 共享
- `POST /v1/vaults/{vault_id}/share`
- `DELETE /v1/vaults/{vault_id}/share/{user_id}`

---

## 12. 合规与隐私

- 隐私最小化：仅收集运营必需元数据。
- 支持数据导出与删除（GDPR/本地法规）。
- 敏感操作留痕，默认不记录明文域名之外的输入内容。
- 定期第三方渗透测试与密码学审计。

---

## 13. MVP 路线图（建议 3 个阶段）

### 阶段 1（8~12 周）
- 单用户保险箱、登录条目、多端同步、自动填充基础。
- 主密码 + 本地生物识别解锁。

### 阶段 2（6~8 周）
- 家庭共享、团队基础权限、导入工具、安全仪表盘。

### 阶段 3（8~10 周）
- 企业功能：审计、策略管控、SCIM/SSO 对接。
- 高级安全：硬件密钥强制、恢复流程增强。

---

## 14. 风险与缓解

1. **密钥管理复杂**：先定义稳定密钥协议版本，做向后兼容。
2. **跨端一致性问题**：统一 Sync 协议测试向量与回放测试。
3. **自动填充兼容性**：按浏览器和系统版本分层适配。
4. **误操作删除**：软删除 + 30 天回收站 + 二次确认。

---

## 15. 技术栈建议（可替换）

- 客户端：Swift/Kotlin/Rust Core（共享加密与同步逻辑）。
- 后端：Go / Kotlin + gRPC/REST。
- 数据层：PostgreSQL + Redis + S3。
- 运维：Kubernetes + Terraform + OpenTelemetry。

> 关键建议：将“加密核心 + 同步协议”抽成跨平台共享库，并通过正式协议文档和测试向量驱动开发，避免各端实现偏差。
