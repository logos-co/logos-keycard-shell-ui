# logos-keycard-shell-ui

`keycard_shell_ui` is the Keycard Shell's app. It shows the Shells connected, lets the person choose
which accounts Logos apps may use (each key leaves the Shell only once its person confirms there),
and lists the accounts offered, with a way to take one back. The signer manager then lists those
accounts beside the keystore's, and the Shell signs each request on its own screen.

No secret crosses it: the keys stay on the card inside the Shell, and its PIN is entered on the
Shell. Everything goes through [`keycard_shell_module`](https://github.com/logos-co/logos-keycard-shell-module).

| On screen | The module's |
|---|---|
| Connected *(firmware, serial)* | `devices` |
| Offer accounts: EVM, native segwit, taproot; Bitcoin or the test networks; account; name | `add_accounts`, then `add_status` until the Shell has answered |
| Offered to apps, connected or not; Remove | `signer_accounts`, `remove_account` |

```sh
nix build .#lgx
```

[`doctests/keycard-shell-ui-e2e.test.yaml`](doctests/keycard-shell-ui-e2e.test.yaml) drives the app
headlessly against `keycard-shell-emulator`, a Shell in software, through the QML inspector.

Licensed under MIT or Apache-2.0.
