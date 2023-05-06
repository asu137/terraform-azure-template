# Terraform 実行手順

## 手順

- 現在設定されているテナント・サブスクリプションを確認

```
$ az account show --output table
```

- tfstateファイル保存用ストレージアカウントの認証情報を取得

```
$ bash auth_storage.sh
```

- Terraformの実行計画を確認

```
$ terraform plan
```

- Terraform 実行

```
$ terraform apply
```

## キー コンテナー 初期設定

※ `terraform apply`を実行し、キーコンテナーを新規作成した場合のみ実施

### アクセスポリシーを追加

アクセスポリシーによって許可されたユーザのみがシークレット情報にアクセスできるため、ユーザに対するポリシーを作成する。

- キー コンテナーの「アクセスポリシー」→ 「作成」
- テンプレート「シークレットの管理」を選択
- 「プリンシパル」設定にて、許可したいユーザを選択
- 以上の内容でアクセスポリシーを作成
    - 「アプリケーション」設定は不要

### SSH秘密鍵を保存

SSH秘密鍵をキーコンテナーのシークレットとして保存し、Bastionから利用できる様にする。

- PowerShellにて以下の操作を実施し、操作対象のサブスクリプションを設定する

```
> Connect-AzAccount
> Get-AzSubscription
> Select-AzSubscription -SubscriptionId xxxxx-xxxxx-xxxxx-xxxxx-xxxxx
```

- 秘密鍵をキーコンテナーへアップロード

```
> $RawSecret = Get-Content <SSH秘密鍵のパスを指定> -Raw
> $SecureSecret = ConvertTo-SecureString -String $RawSecret -AsPlainText -Force
> Set-AzKeyVaultSecret -VaultName "vault" -Name "作成するシークレット名(秘密鍵名と合わせる等)" -SecretValue @SecureSecret
```

## Automation 初期設定

※ `terraform apply`を実行し、Automationアカウントを新規作成した場合のみ実施

### システム割り当てマネージドIDにロールを割り当てる

- Automationアカウント → 「アカウント設定 ID」より 「Azureロールの割り当て」

- 「ロールの割り当ての追加」より追加
    - スコープ
        - リソースグループ
    - 役割
        - `共同作成者`

