# WSL

WSL は将来の対象環境です。Windows 側 path、interop、terminal、credential bridge は machine 固有になりやすいため、共通設定に直接埋め込みません。

WSL で必要になった差分は、OS / WSL 条件分岐または ignored `local/` override として小さく追加します。secret や Windows credential の複製は行いません。
