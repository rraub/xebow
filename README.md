# Overview

Xebow is a [nerves-based](https://nerves-project.org/) firmware for the [Keybow](https://shop.pimoroni.com/products/keybow?variant=21246333190227) keypad.

This project is still in **early development** and only functions as a basic keypad with the ability to cycle through a few LED animations and control sound volume.

# Initial Setup

## Checking out the Project

    $ git clone git@github.com:doughsay/xebow.git
    $ cd xebow

## SSH Access (optional)

If you would like to flash firmware to the MicroSD card without having to remove it from the keybow each time, you will need to set up SSH access.  This also provides access to a running iex shell for running commands directly on the device.

If your SSH public key is not in your home directory's .ssh/ directory with one of the following names, then you can specify the path to your public key by setting the `NERVES_SSH_PUB_KEY` environment variable:

- id_rsa.pub
- id_ecdsa.pub
- id_ed25519.pub

## Building the Firmware

If you have not used nerves to build firmware before, you may need to install several dependencies.  See [https://hexdocs.pm/nerves/installation.html](https://hexdocs.pm/nerves/installation.html) if this is your first time using nerves.

The keybow uses a Raspberry Pi Zero WH, so the target would be `rpi0`.  However, to better support all the keybow features that xebow uses, a custom target has been setup called `xebow_rpi0` that you will need to use instead.  To build and burn the firmware:

    $ export MIX_TARGET=xebow_rpi0
    $ mix deps.get
    $ mix firmware

## Writing the Firmware to the MicroSD Card

Insert the MicroSD card into an card reader attached to your computer and then run:

    $ mix firmware.burn

The `mix firmware.burn` command will try to detect your MicroSD card and offer to write the data to the card.  **IMPORTANT: Triple-check that the device it plans to write to is the MicroSD Card, or you could permanently delete data on another device.**

## Booting the Keybow

Remove the MicroSD card and insert it into the keybow.  Plug the kebow into the computer and wait for it to boot.  Once booted, the keypad should begin cycling all keys through a rainbow of colors.

# Keyboard Layout

The xebow firmware sets up the keybow as a 10-key numpad.  Turn the keypad so the flashing LEDs are on the left of each key and the USB cord is facing right.  In this position, the keypad has the following layout:

```
+-----+-----+-----+
|  7  |  8  |  9  |
+-----+-----+-----+
|  4  |  5  |  6  |
+-----+-----+-----+
|  1  |  2  |  3  |
+-----+-----+-----+
|  0  | l-1 | l-2 |
+-----+-----+-----+
```

The `l-1` and `l-2` keys activate different "layers" of the keypad, which allows mapping additional commands to each key.  For example, holding `l-2` and hitting `7` will trigger a command to flash the keypad red.

## Keyboard Shortcuts

- `l1` + `9`: volume up
- `l1` + `6`: volume down
- `l1` + `8`: mute
- `l2` + `7`: flash keypad red
- `l2` + `9`: flash green
- `l2` + `4`: previous animation
- `l2` + `6`: next animation
