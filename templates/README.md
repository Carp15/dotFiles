# Templates

`templates/` は、将来 chezmoi や Nix + Home Manager などで machine 差分を扱う際の template / module 候補領域です。

現時点では独自 template system、render script、secret injection は実装しません。template 化が必要になったら、共通部分・OS 差分・machine 固有値を先に分類し、secret を source や生成物に含めないことを確認します。
