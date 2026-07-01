# Linux Command Reference

## Purpose

This reference organises Linux diagnostic and administrative commands by operational
task, matching the structure of [`windows-command-reference.md`](windows-command-reference.md)
for consistency across the repository. Commands target systemd-based distributions
(Ubuntu, Debian, RHEL/CentOS) as defined in the repository's environment requirements.

Where a distribution-specific difference exists (notably package management), both
the Debian/Ubuntu (`apt`) and RHEL/CentOS (`yum`/`dnf`) equivalents are provided.

---

## When to Use This Reference

Use this reference when you know the task you need to perform but want to confirm
exact syntax or output interpretation without reopening the full playbook. For
step-by-step diagnostic procedures, use the relevant playbook or networking guide -
this document is a lookup tool, not a procedure guide.

---

## Network Configuration and Diagnostics

| Task | Command | Notes |
|---|---|---|
| View IP addresses | `ip addr show` | Modern replacement for `ifconfig` |
| View a specific interface | `ip addr show eth0` | Replace eth0 with actual interface name |
| View link/interface state | `ip link show` | Shows UP/DOWN and LOWER_UP (physical link) status |
| View routing table | `ip route show` | Default gateway shown on the "default via" line |
| Bring an interface up | `sudo ip link set eth0 up` | Requires sudo |
| Bring an interface down | `sudo ip link set eth0 down` | Requires sudo |
| Release DHCP lease | `sudo dhclient -r eth0` | See [`networking/dns-dhcp-playbook.md`](../networking/dns-dhcp-playbook.md) |
| Renew DHCP lease | `sudo dhclient eth0` | Run after release |
| Test connectivity | `ping -c 4 <host>` | `-c` sets packet count; without it, ping runs continuously |
| Trace route to host | `traceroute <host>` | Add `-I` to use ICMP instead of UDP |
| TCP traceroute (firewall-friendly) | `traceroute -T -p 443 <host>` | More reliable through firewalls than default UDP |
| DNS lookup (detailed) | `dig <host>` | Most detailed DNS query tool |
| DNS lookup (short) | `dig +short <host>` | Returns just the resolved IP |
| DNS lookup with specific server | `dig @8.8.8.8 <host>` | Bypasses configured local DNS |
| Simple DNS lookup | `nslookup <host>` | Available cross-platform; less detail than dig |
| View configured DNS servers | `cat /etc/resolv.conf` | May be managed by NetworkManager or systemd-resolved |
| View DNS status (systemd-resolved) | `resolvectl status` | Modern systems using systemd-resolved |
| Flush DNS cache (systemd-resolved) | `sudo systemd-resolve --flush-caches` | Or `sudo resolvectl flush-caches` on newer systems |
| View ARP/neighbour table | `ip neigh show` | Modern replacement for `arp -a` |
| Test TCP port reachability | `nc -zv <host> <port>` | `-z` scan mode, `-v` verbose |
| Test port (no netcat available) | `timeout 5 bash -c "echo > /dev/tcp/<host>/<port>"` | Built-in bash fallback |
| View listening ports/connections | `ss -tuln` | Modern replacement for `netstat` |
| View active connections with process | `sudo ss -tupn` | Requires sudo to see process names for other users |

Full diagnostic procedures using these commands are in
[`networking/network-troubleshooting-guide.md`](../networking/network-troubleshooting-guide.md).

---

## Wireless Network Commands

| Task | Command | Notes |
|---|---|---|
| Check wireless block status | `rfkill list all` | Shows hardware/software block state |
| Unblock Wi-Fi (software block) | `rfkill unblock wifi` | Common fix for "Wi-Fi disabled" |
| List available networks | `nmcli device wifi list` | NetworkManager-based systems |
| Show current connection detail | `nmcli device wifi show` | Or `iw dev wlan0 link` |
| Connect to a network | `nmcli device wifi connect "SSID" password "pass"` | Replace SSID and password |
| List saved connections | `nmcli connection show` | Shows all configured connections |
| Delete a saved connection | `nmcli connection delete "ConnectionName"` | Forces full reconnection |
| Show signal strength | `iwconfig` (legacy) or `iw dev wlan0 link` | iwconfig deprecated on many distributions |
| Scan for networks (detailed) | `sudo iw dev wlan0 scan` | Requires sudo; more detail than nmcli |

Full wireless diagnostic procedures are in
[`networking/wifi-diagnostic-guide.md`](../networking/wifi-diagnostic-guide.md).

---

## System Information

| Task | Command | Notes |
|---|---|---|
| Hostname | `hostname` | Quick lookup |
| Current user | `whoami` | Quick lookup |
| Current user with groups | `id` | Shows UID, GID, and group memberships |
| OS and version | `cat /etc/os-release` | Most reliable cross-distribution method |
| OS and version (alternate) | `lsb_release -a` | Not installed by default on all distributions |
| Kernel version | `uname -r` | Or `uname -a` for full system info |
| System uptime | `uptime` | Add `-p` for human-readable format |
| Hardware summary | `lshw -short` | May require installation: `sudo apt install lshw` |
| CPU information | `lscpu` | Detailed CPU architecture and core info |
| Memory information | `free -h` | `-h` for human-readable units |

---

## File System and Disk

| Task | Command | Notes |
|---|---|---|
| View disk space by filesystem | `df -h` | `-h` human-readable; add `-x tmpfs` to exclude virtual filesystems |
| View inode usage | `df -i` | Separate from capacity - see [`disk-health-report.sh`](../scripts/linux/disk-health-report.sh) |
| View directory sizes | `du -sh /path/*` | `-s` summary, `-h` human-readable |
| View largest subdirectories | `du -h --max-depth=1 /path \| sort -rh` | Sorted largest first |
| Check filesystem for errors | `sudo fsck /dev/sdX1` | **Unmount the filesystem first** - risk of data loss if run on a mounted filesystem |
| View mounted filesystems | `mount \| column -t` | Formatted, readable output |
| View block devices | `lsblk` | Shows disks, partitions, and mount points in tree form |
| Check SMART disk health | `sudo smartctl -H /dev/sda` | Requires `smartmontools` package |
| View disk I/O statistics | `iostat -x 2 3` | Requires `sysstat` package; 3 samples, 2 seconds apart |

**Package installation for optional tools:**
```bash
# Debian/Ubuntu
sudo apt install smartmontools sysstat lshw

# RHEL/CentOS
sudo yum install smartmontools sysstat lshw
```

---

## Process and Service Management

| Task | Command | Notes |
|---|---|---|
| List running processes | `ps aux` | Full process list with resource usage |
| Top processes by CPU | `ps aux --sort=-%cpu \| head -10` | |
| Top processes by memory | `ps aux --sort=-%mem \| head -10` | |
| Interactive process viewer | `top` | Press `P` for CPU sort, `M` for memory sort, `q` to quit |
| Modern interactive viewer | `htop` | More readable than top; requires installation |
| Kill a process (graceful) | `kill <PID>` | Sends SIGTERM - allows graceful shutdown |
| Kill a process (forceful) | `kill -9 <PID>` | Sends SIGKILL - immediate termination |
| Kill by process name | `pkill processname` | Matches by name rather than PID |
| Find a process's PID | `pgrep processname` | Returns matching PIDs |
| List systemd services | `systemctl list-units --type=service` | All loaded services |
| List failed services | `systemctl --failed` | Quick way to spot service faults |
| Check a specific service status | `systemctl status servicename` | Shows state, recent log lines |
| Start a service | `sudo systemctl start servicename` | Requires sudo |
| Stop a service | `sudo systemctl stop servicename` | Requires sudo |
| Restart a service | `sudo systemctl restart servicename` | Requires sudo |
| Enable a service at boot | `sudo systemctl enable servicename` | Persists across reboots |
| Disable a service at boot | `sudo systemctl disable servicename` | |

---

## User and Account Management

| Task | Command | Notes |
|---|---|---|
| View account status | `sudo passwd -S username` | Shows P (usable), L (locked), NP (no password) |
| View password/account expiry | `sudo chage -l username` | Shows last change, expiry dates |
| Lock an account | `sudo passwd -l username` | Prevents login |
| Unlock an account | `sudo passwd -u username` | Restores login ability |
| Force password change at next login | `sudo chage -d 0 username` | |
| Reset a user's password | `sudo passwd username` | Prompts for new password |
| Add a new user | `sudo useradd -m username` | `-m` creates home directory |
| Delete a user | `sudo userdel -r username` | `-r` removes home directory - use with caution |
| Add user to a group | `sudo usermod -aG groupname username` | `-aG` appends without removing existing groups |
| List a user's groups | `groups username` | |
| View currently logged in users | `who` | Or `w` for more detail including activity |

Full login fault procedures are in
[`playbooks/user-cannot-login.md`](../playbooks/user-cannot-login.md).

---

## Package Management

| Task | Debian/Ubuntu (apt) | RHEL/CentOS (yum/dnf) |
|---|---|---|
| Update package list | `sudo apt update` | `sudo yum check-update` |
| Upgrade all packages | `sudo apt upgrade` | `sudo yum update` |
| Install a package | `sudo apt install packagename` | `sudo yum install packagename` |
| Remove a package | `sudo apt remove packagename` | `sudo yum remove packagename` |
| Remove package and config | `sudo apt purge packagename` | `sudo yum remove packagename` (config removal varies) |
| Search for a package | `apt search keyword` | `yum search keyword` |
| Show package info | `apt show packagename` | `yum info packagename` |
| Fix broken dependencies | `sudo apt --fix-broken install` | `sudo yum-complete-transaction` |
| List installed packages | `dpkg -l` | `rpm -qa` |
| Check if a package is installed | `dpkg -s packagename` | `rpm -q packagename` |
| Find which package owns a file | `dpkg -S /path/to/file` | `rpm -qf /path/to/file` |

---

## Printing (CUPS)

| Task | Command | Notes |
|---|---|---|
| Check CUPS service status | `systemctl status cups` | |
| List printers and status | `lpstat -p -d` | Shows default printer and all configured printers |
| List print queue | `lpstat -o` | Shows pending jobs |
| Cancel all jobs for a printer | `cancel -a PrinterName` | |
| Enable a disabled printer | `sudo cupsenable PrinterName` | |
| Disable a printer | `sudo cupsdisable PrinterName` | |
| Remove a printer | `sudo lpadmin -x PrinterName` | |
| Add a printer (IPP) | `sudo lpadmin -p PrinterName -E -v ipp://host/ipp/print -m everywhere` | |
| Print a test page | `echo "test" \| lp -d PrinterName` | |
| View CUPS error log | `sudo tail -50 /var/log/cups/error_log` | |
| Access CUPS web interface | Browse to `http://localhost:631` | Local access only by default |

Full printer diagnostic procedures are in
[`playbooks/printer-not-working.md`](../playbooks/printer-not-working.md).

---

## Logs

| Task | Command | Notes |
|---|---|---|
| View recent journal entries | `journalctl -n 50` | Last 50 entries |
| View entries since a time | `journalctl --since "1 hour ago"` | Accepts natural language time |
| View entries for a specific unit | `journalctl -u servicename` | |
| Follow logs in real time | `journalctl -f` | Like `tail -f` for the journal |
| View only errors/warnings | `journalctl -p warning` | Priority filter |
| View kernel messages | `dmesg` | Add `\| tail -50` for recent entries |
| View boot history | `journalctl --list-boots` | Useful for correlating issues to a specific session |
| Traditional syslog (if present) | `tail -f /var/log/syslog` | Debian/Ubuntu fallback if journal unavailable |
| Traditional messages log | `tail -f /var/log/messages` | RHEL/CentOS fallback |

Automated log collection is available via
[`scripts/linux/log-summary.sh`](../scripts/linux/log-summary.sh).

---

## Remote Access

| Task | Command | Notes |
|---|---|---|
| SSH to a remote host | `ssh username@hostname` | Standard remote access |
| SSH with a specific key | `ssh -i ~/.ssh/keyfile username@hostname` | |
| Copy a file to a remote host | `scp file.txt username@hostname:/path/` | |
| Copy a file from a remote host | `scp username@hostname:/path/file.txt .` | |
| Test SSH service is listening | `nc -zv hostname 22` | Confirms port 22 is reachable |

---

## Security and Permissions

| Task | Command | Notes |
|---|---|---|
| View file permissions | `ls -la /path` | Shows owner, group, and permission bits |
| Change file permissions | `chmod 755 file` | Numeric mode - see chmod reference for bit meaning |
| Change file owner | `sudo chown user:group file` | Requires sudo unless you own the file |
| Change ownership recursively | `sudo chown -R user:group /path` | Use with caution on shared directories |
| Check AppArmor status | `sudo aa-status` | Debian/Ubuntu mandatory access control |
| Check SELinux status | `sestatus` | RHEL/CentOS mandatory access control |
| View sudo access for a user | `sudo -l -U username` | Shows what commands the user can run with sudo |

---

## Common Command Patterns for Ticket Documentation

```bash
# Redirect output to a file for ticket attachment
ip addr show > ~/diagnostic-output.txt

# Append additional command output to the same file
free -h >> ~/diagnostic-output.txt

# Capture both stdout and stderr
some-command > output.txt 2>&1
```

For structured, repeatable diagnostic collection, prefer the Bash scripts in
[`scripts/linux/`](../scripts/linux/) over manually chaining individual commands -
they produce consistent, ticket-ready output automatically with built-in flagging
of concerning values.

---

## Security Considerations

- Commands requiring `sudo` should only be run with a clear understanding of their
  effect - several modify system-wide configuration or affect other users
- `userdel -r` and `chown -R` are destructive/wide-reaching if run against the wrong
  path - always confirm the target path before executing
- Never run commands found in unsolicited instructions (email, chat, forum posts,
  or piped directly from a URL via `curl | bash`) without independently verifying
  their purpose and source
- `fsck` must never be run on a mounted filesystem - this can cause data loss;
  always unmount first or run from a rescue environment
- When sharing diagnostic output that may include hostnames, internal IP ranges,
  or usernames, follow your organisation's data handling policy before attaching
  to externally visible tickets

---

## Related Documents

| Document | Relationship |
|---|---|
| [`windows-command-reference.md`](windows-command-reference.md) | Windows equivalent reference |
| [`network-ports-protocols.md`](network-ports-protocols.md) | Port and protocol reference for connectivity testing |
| [`../networking/network-troubleshooting-guide.md`](../networking/network-troubleshooting-guide.md) | Full diagnostic procedures using these commands |
| [`../playbooks/`](../playbooks/) | Scenario-specific application of these commands |