source "${BASH_SOURCE%/*}/helpers.bash"

function fwcleanup {
  set +e
  polycubectl firewall del fw
  delete_veth 2
}
trap fwcleanup EXIT

set -e
set -x

create_veth 2

polycubectl firewall add fw
polycubectl firewall fw set loglevel=DEBUG
polycubectl firewall fw ports add fw-p1
polycubectl firewall fw ports add fw-p2
polycubectl firewall fw ports fw-p1 set peer=veth1
polycubectl firewall fw ports fw-p2 set peer=veth2
polycubectl firewall fw set interactive=false

polycubectl firewall fw set accept-established=ON

# Allowing connections to be started only from NS2 to NS1
polycubectl firewall fw chain INGRESS append l4proto=ICMP action=FORWARD
polycubectl firewall fw chain INGRESS apply-rules

polycubectl firewall fw chain EGRESS append l4proto=UDP conntrack=NEW action=FORWARD
polycubectl firewall fw chain EGRESS append l4proto=ICMP action=FORWARD
polycubectl firewall fw chain EGRESS apply-rules

echo "UDP Conntrack Test [Automatic forward][Transaction mode]"

echo "(1) Sending NOT allowed NEW UDP packet"
npingOutput="$(sudo ip netns exec ns1 nping --udp -c 1 -p 50000 -g 50000 10.0.0.2)"

if [[ $npingOutput == *"Rcvd: 1"* ]]; then
  echo "Test failed (1)"
  exit 1
fi

echo "(2) Sending allowed UDP packet"
npingOutput="$(sudo ip netns exec ns2 nping --udp -c 1 -p 50000 --source-port 50000 10.0.0.1)"
if [[ $npingOutput != *"Rcvd: 1"* ]]; then
  echo "Test failed (2)"
  exit 1
fi

echo "(3) Sending allowed ESTABLISHED UDP packet"
npingOutput="$(sudo ip netns exec ns1 nping --udp -c 1 -p 50000 -g 50000 10.0.0.2)"

if [[ $npingOutput != *"Rcvd: 1"* ]]; then
  echo "Test failed (3)"
  exit 1
fi

sleep 5

echo "(4) Sending another allowed ESTABLISHED UDP packet"
npingOutput="$(sudo ip netns exec ns1 nping --udp -c 1 -p 50000 -g 50000 10.0.0.2)"

if [[ $npingOutput != *"Rcvd: 1"* ]]; then
  echo "Test failed (4)"
  exit 1
fi

echo "Test PASSED"
exit 0
