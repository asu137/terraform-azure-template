# Terraform 初期設定

## Azure CLI インストール

- 手元の環境に [Azure CLI](https://docs.microsoft.com/ja-jp/cli/azure/)をインストール
- Azureアカウントにサインイン

    ```
    $ az login
    ```

- 現在設定されているテナント・サブスクリプションを確認

    ```
    $ az account show --output table
    ```

- 所属している別のテナント・サブスクリプションへ変更する場合は、下記コマンドにて変更する

    ```
    テナント・サブスクリプションの一覧を確認
    $ az account list --output table
    別のサブスクリプションをセット
    $ az account set --subscription "<サブスクリプション名>"
    ```

## Terraform インストール

- [tfenv](https://github.com/tfutils/tfenv)を手元の環境にインストール
- [versions.tf](../versions.tf)に記載してあるバージョンのTerraformをインストール

    ```
    $ tfenv install x.x.x
    $ tfenv use x.x.x
    ```

## tfstate保存用のAzureストレージを用意

- Azureリソースグループを作成
    - リソースグループ名: `terraform-tfstate`
- ストレージアカウントを作成 ※tfstate保存用
    - ストレージアカウント名: よしなに
    - BLOBパブリックアクセス: `無効`
    - ネットワークアクセス:「選択した仮想ネットワークとIPアドレスからのパブリック」
        - 作成後、許可したい接続元IPアドレスを設定すること
    - コンテナー
        - `tfstate`
- `versions.tf` にストレージアカウントの情報を入れる

## Terraform セットアップ

- Terraform作業ディレクトリを初期化

```
$ terraform init
```

- `terraform plan`を正常に実行できることを確認

```
$ terraform plan
```

## VNetのアクセスレンジを確認

- `variables.tf`で定義されている `vnet_address_range_prefix` の値を確認
- Azureポータルより「仮想ネットワーク」を確認し、`vnet_address_range_prefix` で設定されているアドレスレンジが使用されていないことを確認
    - `"10.10."` の場合、仮想ネットワークは `10.10.0.0/16` で作成される
- 既に利用されているレンジの場合は、`vnet_address_range_prefix`の値を使われていないレンジへ変更すること

## 備考

- [variables.tf](../variables.tf)の設定値をローカル環境のみ変更したい場合、`terraform.tfvars`を利用することで変数の値を書き換えることができる
