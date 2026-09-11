# PAM stacks

Custom `/etc/pam.d/` files: every prompt asks for the password first and falls
back to [howdy](../howdy/README.md) face recognition when the password is wrong
or empty.

```sh
bash pam.d/apply-pam.sh            # check modules, then install
bash pam.d/apply-pam.sh --check    # check only
bash pam.d/apply-pam.sh --restore  # check, then reinstall archive/
```

**Keep a root TTY open** (`Ctrl+Alt+F2`) until `sudo -k && sudo true` works: a
broken stack locks you out of sudo and polkit.

## How it works

Each file is the stock Arch/vendor file plus two lines:

```
auth  [success=1 authinfo_unavail=die conv_err=die default=ignore]  pam_unix.so
auth  sufficient  pam_howdy.so
```

- correct password: `success=1` skips howdy; the stock stack re-uses the cached
  token, so there is no second prompt
- wrong or empty password: falls through to howdy
- face not recognised: falls through to the stock stack, `pam_faillock` counts
  the attempt
- conversation lost (greeter or hyprlock crashed): aborts instead of opening
  the camera for nobody

| File       | Base                                                           |
| ---------- | -------------------------------------------------------------- |
| `greetd`   | `greetd` package                                               |
| `login`    | `util-linux` package                                           |
| `su`       | `util-linux` package, with the `su.pacnew` changes merged      |
| `sudo`     | `sudo` package, with the `sudo.pacnew` changes merged          |
| `polkit-1` | vendor `/usr/lib/pam.d/polkit-1` (the `/etc` copy overrides it) |
| `hyprlock` | `hyprlock` package, unmodified: inherits howdy from `login`    |

- To turn off face unlock at the login screen only, comment out the
  `pam_howdy.so` line in `greetd`.
- A face match authenticates even while `pam_faillock` has locked out password
  attempts.
- On a `.pacnew` for any of these files, re-apply the two lines on top of the
  new stock file instead of keeping the old one.

## archive/

Snapshot of the live `/etc/pam.d/` files taken on 2026-09-11, before this
setup. Those stacks ran `sufficient pam_unix.so` ahead of the system stack,
which skipped `pam_faillock` entirely.
