[doc("tofu init")]
[working-directory('../infrastructure')]
init *args:
    tofu init {{args}}

[doc("tofu apply, then re-encrypt state (encrypts even on failure)")]
[working-directory('../infrastructure')]
apply *args:
    #!/usr/bin/env bash
    set -e
    trap 'just secrets::encrypt_terraform_state' EXIT
    tofu apply {{args}}

[doc("tofu destroy, then re-encrypt state (encrypts even on failure)")]
[working-directory('../infrastructure')]
destroy *args:
    #!/usr/bin/env bash
    set -e
    trap 'just secrets::encrypt_terraform_state' EXIT
    tofu destroy {{args}}

