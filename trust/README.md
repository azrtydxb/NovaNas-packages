# Trust

Public verification keys for NovaNAS marketplace packages.

`novanas-marketplace.pub` is a [cosign](https://github.com/sigstore/cosign)
public key. Generate the keypair with:

```bash
cosign generate-key-pair
mv cosign.pub trust/novanas-marketplace.pub
# cosign.key — the PRIVATE key — must NEVER be committed to this repo.
# Store it offline (HSM, hardware token, password-manager export).
```

Sign a package:

```bash
cosign sign-blob --key /path/to/cosign.key \
  --output-signature plugin-name-1.0.0.tar.gz.sig \
  plugin-name-1.0.0.tar.gz
```

Verify a package:

```bash
cosign verify-blob \
  --key trust/novanas-marketplace.pub \
  --signature plugin-name-1.0.0.tar.gz.sig \
  plugin-name-1.0.0.tar.gz
```

The OS image bakes the `.pub` file at `/etc/nova-nas/trust/marketplace.pub`.
nova-api reads it and refuses to install unsigned or tampered packages.
