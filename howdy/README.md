For windows-hello like experience install `howdy-git` from AUR.

To setup follow [ArchWiki page](https://wiki.archlinux.org/title/Howdy#Add_correct_IR_sensor)
1. Select correct sensor
2. Update config by running `sudo $EDITOR=vim howdy config`
  - Update device path
  - Optionally update `dark_threshold` to higher value (e.g. 100) if IR emitter blinks.
3. Add your face by running
4. Update PAM configs to allow allow login using howdy
  - copy and replace files from `./pam.d/` to `/etc/pam.d/`
5. Update polkit service to allow using camera: https://github.com/boltgolt/howdy/issues/1077#issuecomment-3693110823
  - run `sudo systemctl edit polkit-agent-helper@.service`
  - add following rows:
    ```conf
    [Service]
    PrivateDevices=no
    DeviceAllow=char-video4linux rw
    ```
  - after save and exit reload service with `systemctl enable --now polkit-agent-helper.socket`
