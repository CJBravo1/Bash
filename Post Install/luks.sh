enroll_luks_tpm() {

  ## Inspect Kernel Cmdline for rd.luks.uuid
  RD_LUKS_UUID="$(xargs -n1 -a /proc/cmdline | grep rd.luks.uuid | cut -d = -f 2)"

  # Check to make sure cmdline rd.luks.uuid exists
  if [[ -z ${RD_LUKS_UUID:-} ]]; then
    printf "LUKS device not defined on Kernel Commandline.\n"
    printf "This is not supported by this script.\n"
    printf "Exiting...\n"
    return 1
  fi

  # Check to make sure that the specified cmdline uuid exists.
  if ! grep -q "${RD_LUKS_UUID}" <<< "$(lsblk)" ; then
    printf "LUKS device not listed in block devices.\n"
    printf "Exiting...\n"
    return 1
  fi

  # Cut off the luks-
  LUKS_PREFIX="luks-"
  if grep -q ^${LUKS_PREFIX} <<< "${RD_LUKS_UUID}"; then
    DISK_UUID=${RD_LUKS_UUID#"$LUKS_PREFIX"}
  else
    echo -e "\e[31mLUKS UUID format mismatch.\e[0m"
    echo -e "\e[31mExiting...\e[0m"
    return 1
  fi

  SET_PIN_ARG=""
  # Always proceed without setting a PIN

  # Specify Crypt Disk by-uuid
  CRYPT_DISK="/dev/disk/by-uuid/$DISK_UUID"

  # Check to make sure crypt disk exists
  if [[ ! -L "$CRYPT_DISK" ]]; then
    printf "LUKS device not listed in block devices.\n"
    printf "Exiting...\n"
    return 1
  fi

    if sudo cryptsetup luksDump "$CRYPT_DISK" | grep systemd-tpm2 > /dev/null; then
    KEYSLOT=$(cryptsetup luksDump "$CRYPT_DISK" | sed -n '/systemd-tpm2$/,/Keyslot:/p' | grep Keyslot|awk '{print $2}')
    echo "TPM2 already present in LUKS keyslot $KEYSLOT of $CRYPT_DISK. Automatically wiping it and re-enrolling."
    sudo systemd-cryptenroll --wipe-slot=tpm2 "$CRYPT_DISK"
fi

  ## Run crypt enroll
  echo -e "\e[32mEnrolling TPM2 unlock requires your existing LUKS2 unlock password\e[0m"
  sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7+14 "$CRYPT_DISK"
# Modify /etc/crypttab to include tpm2-device=auto for the relevant LUKS device
CRYPTTAB_FILE="/etc/crypttab"
sudo cp  "$CRYPTTAB_FILE" "$CRYPTTAB_FILE.bak"
LUKS_NAME=$(lsblk -no NAME,UUID | grep "$DISK_UUID" | awk '{print $1}')


if [ -n "$LUKS_NAME" ]; then
    sudo sed -i "/$LUKS_NAME\|$DISK_UUID/ s/$/ ,tpm2-device=auto/" "$CRYPTTAB_FILE"
    log_message "Added tpm2-device=auto to $CRYPTTAB_FILE for $LUKS_NAME"
else
    log_message "Could not find LUKS device name for UUID $DISK_UUID in lsblk output."
fi
# Regenerate initramfs and update GRUB to accept the new enrollment
if command -v dracut >/dev/null 2>&1; then
    sudo dracut --force
    log_message "Regenerated initramfs with dracut."
fi

if command -v update-grub >/dev/null 2>&1; then
    sudo update-grub
    log_message "Updated GRUB bootloader."
elif command -v grub2-mkconfig >/dev/null 2>&1; then
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg
    log_message "Updated GRUB2 bootloader."
fi

  if lsinitrd 2>&1 | grep -q tpm2-tss > /dev/null; then
    ## add tpm2-tss to initramfs
    if rpm-ostree initramfs | grep tpm2 > /dev/null; then
      echo "TPM2 already present in rpm-ostree initramfs config."
      sudo rpm-ostree initramfs
      echo -e "\e[33mRe-running initramfs to pickup changes above.\e[0m"
    fi
    sudo rpm-ostree initramfs --enable --arg=--force-add --arg=tpm2-tss
  else
    ## initramfs already containts tpm2-tss
    echo -e "\e[33mTPM2 already present in initramfs.\e[0m"
  fi

  ## Now reboot
  echo
  echo -e "\e[32mTPM2 LUKS auto-unlock configured.\e[0m"
}
enroll_luks_tpm 