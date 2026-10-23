# ---------------------------------------------------------------------------
# Two Ubuntu 24.04 instances.
#
# c2-server: nginx with a self-signed certificate and a /checkin endpoint.
#            Plays the "attacker" side of the beacon experiment.
# client:    capture and analysis box (tcpdump, tshark, Zeek, Suricata,
#            mitmproxy) plus the benign beacon script.
#
# Both install their tooling from user_data on first boot. Progress is logged
# to /var/log/blog-lab-setup.log; /var/lib/blog-lab/setup-done appears when
# it has finished.
# ---------------------------------------------------------------------------

# Canonical publishes the current AMI ID here, which avoids an owner/name
# filter that silently picks up the wrong image.
data "aws_ssm_parameter" "ubuntu_2404" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_instance" "c2" {
  ami                    = data.aws_ssm_parameter.ubuntu_2404.value
  instance_type          = var.c2_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.c2.id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name

  user_data                   = file("${path.module}/scripts/c2-server.sh")
  user_data_replace_on_change = true

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 10
    encrypted   = true
  }

  # A newer AMI must not replace a running lab box mid-experiment.
  lifecycle {
    ignore_changes = [ami]
  }

  tags = { Name = "${var.name_prefix}-c2-server" }
}

resource "aws_instance" "client" {
  ami                    = data.aws_ssm_parameter.ubuntu_2404.value
  instance_type          = var.client_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.client.id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name

  user_data = templatefile("${path.module}/scripts/client.sh.tftpl", {
    c2_ip = aws_instance.c2.private_ip
  })
  user_data_replace_on_change = true

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  # Room for pcaps and Zeek/Suricata logs from multi-hour beacon runs.
  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  lifecycle {
    ignore_changes = [ami]
  }

  tags = { Name = "${var.name_prefix}-client" }
}
