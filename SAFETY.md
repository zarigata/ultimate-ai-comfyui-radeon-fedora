# SAFETY GUIDE: KEEP IT FUN, KEEP IT SAFE

This safety guide tells you what our installer does, what to watch out for, and how not to blow up your rig while having a good time.

## 1) What this script does
- Installs ROCm-enabled stacks, downloads and configures ComfyUI, and sets up a GPU workload environment.
- Adds user groups, creates launchers, and downloads model weights when you opt in.
- Runs basic sanity checks to avoid obvious misconfigurations.

## 2) Before you run it
- Read the scripts so you know what changes are being made.
- Back up important data (just in case of a misfire or a power blink).
- Make sure you have a stable internet connection and a cooling setup that won’t punish you later.

## 3) GPU safety
- AI workloads run GPUs hot. Watch temperatures: rocm-smi or watch -n1 sensors.
- Ensure proper cooling (fans, airflow, maybe a desk fan pointed at the case).
- Verify power supply can handle GPU + CPU load, especially on high-end GPUs.
- Don’t run on laptops with insufficient cooling; ROCm on laptops is risky and not officially supported in most cases.

## 4) Power consumption
- Expect higher power draw during heavy generation tasks. Your electricity bill will thank you for the extra air in your room.

## 5) System stability
- ROCm + custom kernels + gaming/desktop OS can be a little spicy. If you hit stability issues, slow down or switch to a safe mode.

## 6) Data safety
- Backups are your friend. The installer is careful, but you should back up anything important.

## 7) Network
- You’ll download models from the internet. Watch data caps and download sizes.

## 8) What the installer will NEVER do (without asking)
- rm -rf, modify boot config, flash firmware
- Install rootkits or anything sneaky. We’re drama-free but we’re not naive.

## 9) Review the code
- It’s open source. Read it, understand it, and give feedback.
