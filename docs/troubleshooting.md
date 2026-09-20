# Troubleshooting

最初の確認は、非破壊の診断から始めます。

```bash
./scripts/doctor.sh
git status --short
git diff --check
```

設定が期待どおり読まれない場合は、対象 CLI の `--help`、設定ファイルの種類・symlink・読み込み経路を確認します。live 設定の置換、symlink の張り替え、package install は、影響と復元方法を確認してから別途行います。認証失敗時に token、cookie、credential file の内容を出力しないでください。
