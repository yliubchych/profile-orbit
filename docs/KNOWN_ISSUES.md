# Known issues and limitations

- This is an unsigned Windows beta. Enterprise execution policies and clean installations on other machines are unverified. No paid signing service was purchased.
- Compatibility depends on the installed desktop app honoring separate data roots and activation links. Diagnostics distinguish locally observed builds from unverified future builds; version recognition is not a comprehensive certification.
- Profile labels are supplied by the user, not verified account identities. Separate folders do not enforce filesystem or employer-policy isolation.
- Full close forcefully interrupts the selected profile's tasks. It preserves disk data, warns in the UI, and rechecks process identity; it does not inspect whether agent work is complete.
- Local tests cover dispatch of the documented workspace link. Signed-in navigation across every supported desktop version and independent beta installations remain unverified.
- The Windows Forms process/window queries are synchronous. Cold launches may keep the launcher busy for up to the 30-second wait; this does not stop running Codex tasks.
- Global hotkeys can conflict with other apps; unavailable bindings are reported and tray actions remain available. Native registration tests do not run successfully inside the restricted agent sandbox.
- Closing/minimizing the new launcher hides it to the tray; use **Exit launcher** to quit. Old monolithic launcher processes from before this upgrade do not participate in the new singleton protocol.
- Removal preserves account data, unknown files and edited application files. A retained data folder is intentional, not a complete wipe.
