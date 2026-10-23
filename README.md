# blog-lab

A disposable AWS lab for the blog post *"What Your Security Team Can Still See When Everything Is Encrypted."* It covers encrypted-traffic metadata, beacon detection, and TLS inspection, all on infrastructure and traffic I own.

```
VPC 10.50.0.0/16 (us-west-2), one public subnet, no NAT
├── client     t3.small   tcpdump, tshark, Zeek, Suricata + ET Open, mitmproxy, beacon/capture helpers
└── c2-server  t3.micro   nginx, self-signed cert, GET /checkin -> 200
```

- **No inbound from the internet.** Access is through SSM Session Manager only, with no SSH port and no key pair. The c2-server accepts 443 from the client security group only.
- **IMDSv2 required**, encrypted gp3 volumes, and an instance role limited to `AmazonSSMManagedInstanceCore`.
- **Budget:** $20/month, filtered on `Project=blog-lab`. Alerts go out at 50% actual and 100% forecast.
- **State:** `s3://andyziber-tfstate/blog-lab/terraform.tfstate` (the same bucket as the portfolio stack, with native lockfile locking).

## Prerequisites

- Terraform >= 1.11 (`winget install Hashicorp.Terraform`)
- AWS CLI v2 plus the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
- Credentials for the **personal** account (the one that owns `andyziber-tfstate`)
- `Project` active as a cost allocation tag (Billing → Cost allocation tags), or the budget filter matches nothing

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # set alert_email
terraform init
terraform plan
terraform apply
```

First-boot setup takes about 5–10 minutes. Check that it finished before you start working:

```bash
aws ssm start-session --target <client_instance_id>     # from `terraform output`
sudo -i                                                  # loads C2_IP, LAB_IFACE, Zeek PATH
tail -f /var/log/blog-lab-setup.log
ls /var/lib/blog-lab/            # setup-done = finished; failed = list of steps to redo by hand
```

Confirm the budget email subscription when AWS sends it.

## Between sessions: stop, don't leave running

```bash
terraform output -raw stop_all | sh     # or copy the command
terraform output -raw start_all | sh
```

Stopped instances only bill for EBS (about 40 GB of gp3). Public IPs change on every start; the private IPs, and therefore `C2_IP`, stay the same.

## Teardown (Day 9)

```bash
terraform destroy
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=blog-lab --region us-west-2
```

The second command should return an empty list, apart from the budget, which `destroy` also removes.

## Experiment cheat sheet

All commands run on the client as root (`sudo -i`).

**Exp 1: what encryption leaks**
```bash
capture baseline &                     # start a capture in the background
curl -s https://example.com -o /dev/null
curl -sk https://$C2_IP/checkin
curl -s http://neverssl.com -o /dev/null        # plaintext, for contrast
kill %1
zeek -C -r ~/captures/baseline-*.pcap          # writes conn.log, ssl.log, x509.log, dns.log here
zeek-cut server_name version cipher < ssl.log
```

**Exp 2: catch the beacon**
```bash
capture beacon "host $C2_IP" &
beacon 60 10                            # leave it running for 2+ hours (inside tmux)
# afterwards:
zeek -C -r ~/captures/beacon-*.pcap
zeek-cut ts id.resp_h id.resp_p duration orig_bytes resp_bytes < conn.log
suricata -r ~/captures/beacon-*.pcap -l /tmp/suri && jq 'select(.event_type=="tls")' /tmp/suri/eve.json | head
```
RITA isn't installed automatically. Its installer changes between releases, so follow the current [RITA instructions](https://github.com/activecm/rita) by hand on Day 6.

**Decrypting curl's own TLS** (curl honours `SSLKEYLOGFILE`):
```bash
SSLKEYLOGFILE=/root/sslkeys.log curl -s https://example.com -o /dev/null
# copy the pcap and the key log to your laptop, load the log in Wireshark
# (Preferences > Protocols > TLS), then delete sslkeys.log on both ends.
```

**Exp 4: TLS inspection**
```bash
mitmdump --listen-port 8080 &
curl -s --proxy http://127.0.0.1:8080 --cacert ~/.mitmproxy/mitmproxy-ca-cert.pem https://example.com -o /dev/null
openssl s_client -connect example.com:443 -servername example.com </dev/null 2>/dev/null | openssl x509 -noout -issuer
curl -s --proxy http://127.0.0.1:8080 --cacert ~/.mitmproxy/mitmproxy-ca-cert.pem \
  --pinnedpubkey "sha256//<real-key-hash>" https://example.com    # fails: pinning detects the swap
```

**Zeek JA3/JA4:** these come as zkg packages, not with base Zeek. Install them by hand (`zkg autoconfig`, then the package name from FoxIO's current JA4 README) so a renamed package doesn't break first-boot setup.

## Ground rules

- Only this lab's instances and public sites I browse normally. No scanning, and no real C2 frameworks.
- The "beacon" is `curl` in a loop to my own server. It carries no payload.
- Captures and key logs never get committed (see `.gitignore`). Redact IPs and account IDs before anything is published.
- SSM's own agent traffic (`ssmmessages.us-west-2.amazonaws.com`) shows up in captures. Filter it out, or use it as an example of legitimate TLS SNI.
