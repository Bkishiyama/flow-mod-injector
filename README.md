<p align="center">
  <img src="docs/netocto.jpg" width="350">
  <img src="docs/masked.jpg" width="350">
</p>


# Tool 3: FlowMod Injector Tool



---

## Video Presentation

IN PROGRESS - UPDATE and REMOVE when completed

Watch my videos:

> 🎥 [SDN FL Anomaly Detection Tool](https://youtu.be/ba_NrpwrSyE)  
> 📚 with [Docker copy-and-paste commands](https://1drv.ms/w/c/0b9ef4570f82165e/IQD-QWe9zvwpRKE1oNgw0TT4ATfUrsw-xcZuEtRkoxQL8yA?e=jBDDw0)

IN PROGRESS - UPDATE video and REMOVE when completed

---

## Table of Contents

1. Section I: Problem Definition
2. Section II: System Design
3. Section III: Evaluation
4. Quick Start
5. Installation
6. How to Run the Experiment
7. CLI Reference
8. Repository Structure
9. Known Issues

---

## Section I: Problem Definition

### Problem Statement

A Software-Defined Network (SDN) puts all the decision-making for routing and forwarding in one place, making it easier to control the network, but also making it a bigger target for attacks. The controller talks to each switch using a persistent connection, and in most cases, like with the Ryu controller and Open vSwitch, this connection isn't encrypted and doesn't require authentication. This means that all the messages between the controller and the switch are sent as plain text, which is a security risk. Every time the controller sends a message to a switch, or the switch sends one back, it's transmitted without any encryption, making it easy for someone to intercept and read.

This project demonstrates the consequences of that design choice. An adversary who gains local access to the machine running the controller, through a compromised host, a malicious insider, or a lateral movement from the data plane, can observe the entire OpenFlow control stream in real time by using a raw socket and a packet filter. Furthermore, the same adversary can connect directly to the switch as a second controller, complete a OpenFlow handshake, and inject a crafted FlowMod message that permanently rewrites the switch's forwarding rules. The primary controller is excluded from this action and will not be aware of this.

This attack is subtle. It doesn't overwhelm the network or cut off all connections. Instead, it adds a special rule that blocks one specific type of traffic, i.e., HTTP traffice, which uses TCP port 80. All other types of traffic, like ICMP, are not blocked and appear to work. If a network administrator checks the connections between hosts using a standard method, everything seems to be working normally. They'll get the responses they expect, and the network will appear to be healthy. But, the targeted HTTP service is completely inaccessible until someone manually removes the blocking rule from the flow table.

This is what makes a this Denial of Service unique; it's created to avoid detection of monitoring systems that would catch brute-force attacks. Moreover, it takes advantage of a weakness, the unencrypted OpenFlow control channel, that's commonly found in most SDN research and production environments by default.

### Importance

The OpenFlow control channel is similar to a central command center that lets a controller make decisions about how data is forwarded on every switch in its network - without any routers. If a hacker compromised this channel, it would not just affect one computer or one flow of data. The hacker would gain the power to change the entire network's logic from a single point. This is different from a brute-force attack, which appears as an obvious attempt to break in. A FlowMod injection, on the other hand, is a stealthier attack that leaves no trace of an error in the controller's log. It also has no unusual activity in ping statistics, and no warning signs in standard network monitoring tools. The reason this attack is mostly successful is that it blends in with normal network operations, which makes it difficult to detect.

This should be addressed not only in networks, but in a lab setting. SDNs are used in real-world environments, such as company data centers, university networks, and cloud infrastructure. In these places, the Ryu and OVS stack or similar OpenFlow-based systems handle actual traffic. But here's the issue: the control channel is often left unencrypted because setting up TLS is a hassle and people don't understand the threat. Most people assume that the control plane is safe from attackers because it's physically or logically isolated. But Tool 3 shows that's not true. If someone has local access, like an insider, they can manipulate the switch's flow table and do not need special privileges. The assumption of safety is a mistake; systems need to be secured. The unencrypted control channel makes it vulnerable to attacks, and Tool 3 demonstrates how easily an attacker can exploit this weakness. Local access is enough to corrupt the flow table; Tool 3 highlights the need for better security measures to protect these critical systems.

Tool 3 shows its importance by sneaking past security measures without being detected. This is because the security rule is set up to only block certain types of internet traffic, specifically the kind that uses a certain port. The tool uses a different kind of internet traffic, called ICMP, which is not blocked by the rule. This means that even if the tool is being used to disrupt the network, the network will still seem to be working fine if someone is checking it with a simple ping test. Most basic network monitoring systems rely on these kinds of tests to make sure everything is running smoothly. So, even though the network might seem okay, it could actually be having issues that aren't being detected. This tool is designed to show just how big the difference can be between what the network seems to be doing and what's really going on.

### Existing Approaches

To protect the connection between the controller and the switch, the OpenFlow specification has a special secure mode. This mode uses Transport Layer Security (TLS), which is a protocol that secures data, in transit, by providing encryption, authentication, and integrity. As both the controller and the switch use TLS, their conversation is wrapped in an encrypted session. If someone is listening in on the same network, they can't understand what's being said. Also, if someone tries to join the conversation without the right certificate, they'll be rejected before they can even start talking. This is a strong defense against certain kinds of attacks, like Tool 3’s attack. It's an important way to keep the network safe and secure.

In real-world situations, not many people use TLS. When you set up Ryu, it normally listens on a regular TCP port. And when you set up OVS, it connects to controllers using regular TCP. To use TLS, you need to create and share certificates with every switch and controller, manage a certificate authority, and deal with certificate rotation. This is a lot of extra work that many researchers and some production environments don't want to bother with, or don’t fully understand. As a result, most OpenFlow networks that are in use, including all the standard Mininet environments, have a control channel that can be easily read and modified by any local process that has access to raw sockets. This means that anyone with the right access can see and change the data being sent over the network.

Beyond TLS, several complementary defenses have been proposed. Controller-side FlowMod auditing can inspect every rule before it is acknowledged, flagging entries with unexpected cookies, unusually high priorities, or source sessions that do not correspond to the primary controller connection. Role-based access control in OpenFlow 1.3 allows a master controller to demote competing connections to slave status. This would, in theory,  prevent them from modifying flow tables. Tool 3 demonstrates a requested equal role before sending a FlowMod message. The switch accepts the message and the role change without challenge. Continuous flow-table monitoring using ovs-ofctl or equivalent tooling can detect rogue rules after the fact by comparing the live flow table against an expected baseline. None of these approaches are enabled by default in a standard Ryu and OVS deployment.


### The Issue

The main issue that Tool 3 is trying to fix is that the connection between Ryu and OVS, which is used to control the flow of traffic, is not secure. By default, this connection is not authenticated or encrypted, which means that anyone with access to the local network can potentially interfere with it. This is a problem because it would allow an attacker to make permanent changes to a switch's flow table, which could have serious consequences, such as a TCP connection.

The attack path has four steps. First, the injector passively sniffs the loopback interface and confirms that OpenFlow messages are visible in plaintext. This demonstrates the surveillance capability that precedes any targeted injection. Second, it opens a direct TCP connection to the passive OVS listener on port 6654, which was enabled in topology.py to simulate the access a compromised host or insider would have to the switch's management interface. Third, it completes a standard OpenFlow 1.3 handshake, i.e., Hello, Features Request and a Features Reply - that establishes a session that OVS treats as a legitimate second controller. Fourth, it requests an “equal” role to bypass Ryu's master lock, then sends a crafted OFPT_FLOW_MOD message encoding three OXM match fields: ETH_TYPE equal to 0x0800 for IPv4, IP_PROTO equal to 6 for TCP, and TCP_DST equal to 80 for HTTP. No instructions are appended to the FlowMod body. In OpenFlow 1.3, the absence of instructions is an implicit drop. As a result, OVS installs the rule and silently discards every matching packet.

The rule has a high priority, 40,000, which is much higher than the default rules set by Ryu's learning switch, with a priority of 1. In OpenFlow, higher numbers means higher priority - unlike router priority. This rule is also permanent because its idle and hard timeouts are set to zero. The rule includes a special cookie, 0xDEADBEEFCAFE0001, which can be seen when using ovs-ofctl to look at the flow rules, but Ryu's standard controller doesn't check the flow table for unexpected rules. So, Ryu doesn't even know this rule exists. It keeps collecting flow statistics and watching the FL upload endpoint, but it doesn't flag anything out of the ordinary in its logs. The only pattern that appear strange is that HTTP flows from h1 to h2 stop sending bytes. But this could just be normal changes in traffic, not an attack. In essence, Ryu doesn't suspect a thing:

- The rule's high priority means it takes precedence over other rules. 
- Permanent means the rule will not be removed unless manually deleted. 
- The special cookie is a unique identifier for the rule, but Ryu doesn't monitor for it. 
- Because Ryu is not awareness of the rule, it can't delete it. 
- If HTTP stops, it could be noticeable but attributed to various reasons.
 
This situation highlights a potential vulnerability in Ryu's controller, where a malicious rule can be inserted without being detected. The fact that the rule is permanent and has a high priority makes it even more concerning, as it can persist and override other rules without being noticed.

This tool takes advantage of a problem. SDNs do not have a way to detect, stop, or warn about fake flow rules that are sent through an unsecured control channel. To fix this, security needs to be added at a lower level. Meaning, TLS should still be used rather than relying on machine learning models at a higher level. Systems need to secure the connection and not just improve algorithms to analyze the data. By using TLS, any data sent over the control channel is encrypted and authenticated. This makes it much harder for an attacker to inject fake flow rules. In turn, this is a critical step in securing SDN deployments and preventing potential attacks.


---

## Section II: System Design

### Architecture for Tool 3

![Architecture Diagram](docs/flow-mod-injector.drawio.svg)

Host 7 (h7) is the attacker that injects a rule into switch 1 (s1) to drop http traffic. s1 believes h7 is the controller. h1 can no longer send http traffic to h2; however, pings go through. The Ryu controller is unaware of the attack.

---

#### topology.py

This file builds the Mininet virtual network for Tool 3. Inside this file, the `build()` method:

- Creates three switches (s1, s2, s3) and seven hosts (h1–h6 and h7 as the attacker)
- Links hosts to their assigned switches: h1, h2, and h7 to s1; h3 and h4 to s2; h5 and h6 to s3
- Links switches to each other in a line: s1 ↔ s2 ↔ s3
- Assigns static IPs and MACs to every host so the topology is reproducible across machines
- Places h7 on s1 and the injected FlowMod affects traffic between h1 and h2 on s1

The `run()` method extends the Tool 1 and Tool 2 setup with two additions for Tool 3:

- Configures a passive OVS listener on s1 at `ptcp:6654` alongside the existing Ryu connection at `tcp:127.0.0.1:6633`, giving the injector a direct OpenFlow entry point to the switch without disrupting the primary controller session
- Starts an HTTP server on h2 at port 80, establishes an application-layer target that is reachable before injection and then unreachable after it

The traffic generation methods are:

- `start_benign_traffic()`: Starts normal background traffic including iperf3 TCP and UDP streams, periodic pings, and HTTP requests from h1 to h2 at port 80, establishing a baseline flow pattern in live_client1.csv before the attack fires
- `start_attack_traffic()`: Starts Tool 1's malicious traffic, DDoS SYN flood from h4 and port scan from h6, for labeling and testing
- `start_inject_attack()`: Launches injector.py from h7 using --skip-sniff, triggering Phase 2 after 10 seconds of benign baseline traffic so the before and after is visible in the collected flow data
- `label_attack_flows()`: Records the attack window timestamp and prints the labeling command for post-processing with label_window.py
- `run()`: Starts Mininet, configures the passive OVS listener, launches traffic generators in sequence, and drops into the interactive CLI - for manual verification


#### ryu_collector.py

This file is the Ryu controller application that manages the virtual network and collects flow statistics. The `SDNSanitizerController` class is the data traffic manager that:

- Negotiates the OpenFlow session when a switch connects: Ryu asks what OpenFlow features the switch supports and installs a table-miss flow entry so unmatched packets are forwarded to the controller rather than silently dropped
- Handles packets that switches send to the controller, such as unknown MACs, ARP requests, and packets that miss the flow table, and installs learned forwarding rules reactively
- Receives flow statistics reports from switches: number of bytes, packets, duration, and match fields, and then writes them to per-client CSV files
- Polls all connected switches on a fixed interval to collect updated stats continuously throughout the experiment

In summary, this file has been extended across all three tools. I first built `ryu_collector.py` for Tool 1 to handle SDN flow log collection. I expanded it for Tool 2 to act as the REST API interface for the federated learning system, adding endpoints that upload client metrics, receive Isolation Forest parameters, trigger federated aggregation, and report client status back to the controller.

For Tool 3, I made no code changes to `ryu_collector.py`. The injector bypasses this file entirely by connecting directly to Open vSwitch rather than communicating through the Ryu REST API. After the FlowMod is injected, the collector continues running and polling normally, but the flow statistics it records for s1 will show HTTP traffic from h1 to h2 dropping to zero bytes and zero packets. The controller never receives an alert, never logs a warning, and never learns a foreign rule was installed. The evidence is shown from the controller's perspective is the statistical change in the CSV data, which is what Tool 1's Isolation Forest is trained to detect.


#### Summary

In summary, the Tool 3 pipeline:

1. topology.py builds the Mininet network with three switches, seven hosts, and a passive OVS listener on s1 at port 6654
2. ryu_collector.py runs on the Ryu controller and records live flow statistics from every switch into CSV files
3. injector.py Phase 1 passively sniffs the loopback interface and decodes OpenFlow messages on TCP port 6633, confirming the control channel is unencrypted and visible
4. injector.py Phase 2 connects directly to s1, completes an OpenFlow 1.3 handshake, requests EQUAL role to bypass Ryu's MASTER lock, and injects a permanent high-priority FlowMod that drops all TCP port 80 traffic
5. ryu_collector.py continues recording flow statistics; HTTP flows from h1 to h2 on s1 drop to zero bytes, capturing the attack's footprint in live_client1.csv automatically
6. ovs-ofctl dump-flows confirms the rogue rule is installed in s1's flow table with the attacker cookie visible
7. Mininet CLI verification will prove the evasion; curl to h2 times out while ping to h2 succeeds - shows the network as healthy to monitoring while the targeted service is unreachable


#### Tool 3 Development

| Module | File | Responsibility | Tool |
|---|---|---|---|
| Feature Extractor | `src/features.py` | Normalize numeric fields, encode protocol/ports, compute derived features | Tool 1 |
| Local Trainer | `src/local_train.py` | Train Isolation Forest per client; save model bundle | Tool 1 |
| Federated Aggregator | `src/federated.py` | Load client models; average anomaly scores; consensus threshold; calls sanitizer before FedAvg; logs per-round auidt CSV | Tool 1 & 2 |
| Detection Engine | `src/detect.py` | Score new flows; annotate with `anomaly_score`, `is_anomaly`, `anomaly_rank` | Tool 1 |
| Evaluator | `src/evaluate.py` | Compute accuracy/precision/recall/F1/AUC; confusion matrix plots | Tool 1 |
| CLI | `src/cli.py` | Argparse-based interface wiring all modules | Tool 1 |
| CLI root | `cli.py` | Extends Tool 1 CLI with sanitize, demo, and extended simulate-fl commands; adds --inject flag for Tool 3 | Tool 2 & 3 |
| Data Generator | `scripts/generate_data.py` | Synthetic SDN flow CSV generator for quick-start testing | Tool 1 |
| Sanitizer | src/sanitizer.py | Z-score Byzantine-robust aggregation; detects and drops poisoned client uploads before FedAvg; generates per-host audit reports | Tool 2 |
| Poisoned Host | sdn_mininet/poisoned_host.py | Simulates a compromised Mininet host uploading malicious model metrics to the Ryu controller; standalone demo mode | Tool 2 |
| Ryu Controller | sdn_mininet/ryu_collector.py | L2 learning switch; flow stats collector; adds REST endpoints for FL uploads and sanitized aggregation; records HTTP flow drop on s1 after FlowMod injection | Tools 1, 2, 3 |
| Topology | sdn_mininet/topology.py | Builds 3-switch 7-host Mininet network; configures passive OVS listener on s1 at ptcp:6654; starts HTTP server on h2; launches injector from h7 via --inject flag | Tools 1, 2, 3 |
| Flow Mod Injector | sdn_mininet/injector.py | Phase 1: passively sniffs TCP/6633 loopback to confirm unencrypted control channel; Phase 2: connects to s1 passive listener, completes OF 1.3 handshake, requests EQUAL role, injects permanent high-priority DROP rule for TCP/80 | Tool 3 |

---

### Feature Engineering

Feature engineering is the process of transforming raw data into meaningful numerical inputs that a ML model can interpret and learn from.
It involves the process of selecting, extracting, or constructing features that capture patterns in the data.
This is essential for improving model performance. 
In this system, each raw flow is represented using eight numeric features.

IN PROGRESS - UPDATE and REMOVE when completed

| Feature | Description |
|---|---|
| `bytes` | Total bytes transferred (normalized) |
| `packets` | Total packet count (normalized) |
| `duration` | Flow duration in seconds (normalized) |
| `bytes_per_packet` | Derived: bytes divided by packets |
| `packet_rate` | Derived: packets divided by duration |
| `protocol_enc` | Encoded: TCP=0, UDP=1, ICMP=2, Other=3 |
| `src_port_bin` | Binned: system (0-1023)=0, registered=1, dynamic=2 |
| `dst_port_bin` | Binned: same bins as src |

### Federated Aggregation Design

I use a **Score Ensemble**  aggregation strategy.   
This is where each client uses its own model and scaler to assign an anomaly score to new network flows. 
All clients send these scores to the central model, in which they are averaged to produce a final global anomaly score. 
The client's raw data is not shared with the central model - only the computed scores. 

IN PROGRESS - UPDATE and REMOVE when completed

### Technology Choices

| Component | Choice | Justification |
|---|---|---|
| Language | Python 3.8+ | For analysis and ML |
| ML | scikit-learn IsolationForest | Lightweight |
| Data | pandas, numpy | Fast flow log processing |
| Serialization | joblib | Fast sklearn model pickling |
| CLI | argparse | No extra dependencies & easy to extend |
| Config | PyYAML | Easy to read FL simulation config |
| Graphs | matplotlib, seaborn | Standard evaluation |

IN PROGRESS - UPDATE and REMOVE when completed

---

## Section III: Evaluation

### Testing Methodology

#### Overview
Tool 3 is a bit different from Tools 1 and 2. Tool 3 attacs at the network layer. Tool 2 attacked the FL learning model. I do not generate the standard metrics, e.g., F1 score or confusion matrix. To evaluate Tool 3, I look to see if the injected FlowMod disrupts HTTP traffic but allows pings to go through. 
The system includes a **synthetic SDN flow generator** (`scripts/generate_data.py`). 

I use three phases to evaluate Tool 3.

#### Phase 1

Phase 1 of the injector demonstrates that the OpenFlow control channel is readable and there is no decryption or special access. The evaluation criterion is simple. When the injector runs in sniff mode, it must decode and print at least one valid OpenFlow 1.3 message from the loopback interface before Phase 2 starts.

```text
[SNIFF] -> message in plain text
[*] Traffic is unencrypted
[*] Phase 2 can now start
```

This confirms that Ryu's keepalive messages, handshakes, and flow statistics requests are all transmitted in plaintext and fully parseable by a passive observer without credentials.

#### Phase 2

In Phase 2, the FlwoMod injection is accepted by the Open vSwitch and gets installed into s1's flow table. The command used to verify this:

```bash
sudo ovs-ofctl dump-flows s1 -O OpenFlow13
```

In turn, the following result will appear:

```text
cookie=0xdeadbeefcafe0001, priority=40000,
tcp, tp_dst=80, actions=drop
```

| Property | Expected Value | Notes |
|---|---|---|
| cookie | 0xdeadbeefcafe0001 | This indicates the injected rule is from attacker and not Ryu |
| priority | 40000 | Overrides any of Ryu's rules due to higher priority |
| match | tcp,tp_dst=80 | Only HTTP(80) is affected |
| actions | drop | packets get dropped |
| idle_timeout | default=0 | Rule never expires if inactive |
| hard_timeout | default=0 | Rule remains with no expiration |

If no results are shown, FlowMod is not successful. TLS is not used so it should be successful; otherwise, it's a programming issue.

#### Phase 3

The evasion property is the defining characteristic of a surgical DoS and is evaluated using two commands run back to back inside the Mininet CLI, against the same target host, after injection.

##### Test 1: Service Disruption

Users should see a mininet CLI in Terminal 2.

```bash
mininet> h1 curl --max-time 3 http://10.0.0.2/
```

A user can verify it is working by observing a connection timeout or seeing "Operation timed out." This means HTTP traffic has stopped and h2 does not receive traffic from h1 - it has stopped by s1.

##### Test 2: Evasion Occurs

In the mininet CLI, in Terminal 2:

```bash
mininet> h1 ping -c 3 10.0.0.2
```

h1 pings h2 successfully with 0% packet loss. Only HTTP traffic is stopped. All other traffic, such as ICMP, should flow.

### Dataset

Tools 1 and 2 used a dataset. Tool 3 does not use a dataset for testing. It uses live traffic that is generated by this experiment in topology.py. HTTP traffic can be generated between h1 and h2 with topology.py's ```start_benigh_traffic()``` function. The injection is made by injector.py. All flow statistics are recorded during this process with ryu_collector.py and saved in data/live_client1.csv. 

### Results

For Tool 3, all phases tested and passed. As with previous tools, Ubuntu 20.04 inside of VirtualBox is used. Mininet installed within this, version 2.3.1, along with Ryu controller, version 4.34. The Open vSwitch is version 2.13.8. Python 3.8 is used in Ubuntu 20.04 and not upgraded. 

In summary, testing includes the passing of each of these tests:

| Test | Results |
|---|---|
| Phase 1: sniff decodes OpenFlow message | ECHO_REQUEST in plaintext is seen |
| Phase 2: handshake | HELLO, FEATURES_REPLY is seen |
| EQUAL role request: accepted | ROLE_REPLY type=25 is seen |
| FlowMod rule installed in s1 | look for cookie=0xdeadbeefcafe0001 with dump-flows |
| HTTP from h1 to h2 is blocked | times out is seen |
| h1 pings h2 | ICMP traffic shows 0% packet loss |

Tools 1 and 2 are not tested. Further testing should show any TCP/HTTP traffic is dropped from Tool 1. Tool 2 should not affect this testing since it is limited to the FL model and poisons the metrics that flow on a separate path.

---

## Quick Start

IN PROGRESS - UPDATE and REMOVE when completed

### Option 1: Synthetic pipeline (any OS)

```bash
git clone https://github.com/Bkishiyama/sdn-poison-guard.git
cd sdn-fl-detector
python3 -m venv venv
source venv/bin/activate
pip3 install -r requirements.txt
make all
```

### Option 2: Docker (any OS, no Python needed)

```bash
git clone https://github.com/Bkishiyama/sdn-fl-detector.git
cd sdn-fl-detector
docker compose up
```

### Option 3: Live Mininet + Ryu (Ubuntu 20.04 VM only)

```bash
git clone https://github.com/Bkishiyama/sdn-fl-detector.git
cd sdn-fl-detector
chmod +x install.sh
./install.sh
```

Then follow the Live Mode steps below.

---

## Installation
IN PROGRESS - UPDATE and REMOVE when completed
### Requirements

- Python 3.8+
- Ubuntu 20.04 (for live Mininet mode only)
- Docker (for Docker mode only)

### pip

```bash
pip3 install -r requirements.txt
```

### Conda

```bash
conda env create -f environment.yml
conda activate sdn-fl-env
```

### Verify

```bash
python3 cli.py --help
```

---

## How to Run
IN PROGRESS - UPDATE and REMOVE when completed
### Method 1: Synthetic Pipeline

```bash
# Generate synthetic SDN flow data
python3 cli.py generate-data --out-dir data/ --n-clients 3 --n-benign 2000 --n-attack 400

# Train local models
python3 cli.py train-local --data data/client1.csv --out models/client1.pkl --client-id client1
python3 cli.py train-local --data data/client2.csv --out models/client2.pkl --client-id client2
python3 cli.py train-local --data data/client3.csv --out models/client3.pkl --client-id client3

# Aggregate into global federated model
python3 cli.py federated-aggregate --models "models/client*.pkl" --out models/global.pkl

# Detect anomalies
python3 cli.py detect --model models/global.pkl --data data/new_flows.csv --top-n 10 --out results/detections.csv

# Evaluate
python3 cli.py evaluate --model models/global.pkl --data data/test_labeled.csv \
                        --local-models "models/client*.pkl" --out results/
```

Or run everything in one command:

```bash
make all
```

---
### Method 2: Docker
IN PROGRESS - UPDATE and REMOVE when completed
#### Step 1: Install Docker**

Go to the website and install Docker on Windows, Linux, or MAC

Example install on Linux, Ubuntu 24.04

**1. Set up Docker apt repository**
```
# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
```

**2. Install the Docker packages**
```
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```


**3. Verify that the installation by viewing message**
Verify installation by running the following:
```
sudo docker run hello-world
```
>[!Note]After installation, you can verify Docker is running
```
sudo systemctl status docker
```

>[!Note]If it is not running, start it, then run hello world
```bash
sudo systemctl start docker
```

#### Step 2: Add yourself to the Docker group

```bash
sudo usermod -aG docker $USER
newgrp docker
```

#### Step 3: Clone the repo

```bash
git clone https://github.com/Bkishiyama/sdn-fl-detector.git
cd sdn-fl-detector
```

#### Step 4: Build and Run

```bash
docker compose up
```

#### Step 5: View results

Results are printed to your screen and also saved to `./results/` on your host machine.

#### Step 6: Clean up

```bash
docker compose download
```

> **Note:** Docker runs the synthetic pipeline only. Mininet live mode requires Ubuntu 20.04 natively.

---

### Method 3: Live Mode (Mininet + Ryu, Ubuntu 20.04)

#### Topology

![Controller Diagram](docs/ryu_controller.drawio.svg)

#### Step-by-Step

**Step 1: Install (one time):**
```bash
chmod +x install.sh
./install.sh
source ~/.bashrc
```

**Step 2: Terminal 1, start Ryu:**
```bash
cd ~/sdn-fl-detector
ryu-manager sdn_mininet/ryu_collector.py --observe-links
```

**Step 3: Terminal 2, start Mininet:**
```bash
cd ~/sdn-fl-detector
sudo python3 sdn_mininet/topology.py --time 120 --attack
```

**Step 4: Terminal 3, watch flows:**
```bash
watch -n 5 wc -l ~/sdn-fl-detector/data/live_client*.csv
```

**Step 5: Label attack flows**
Use timestamp printed in Terminal 2:
```bash
python3 sdn_mininet/label_window.py \
  --file data/live_client2.csv \
  --all \
  --label 1
```
  
(Optional) To narrow the time frame
```bash
python3 sdn_mininet/label_window.py \
  --file data/live_client2.csv \
  --start "YYYY-MM-DDTHH:MM:SS" \
  --end   "YYYY-MM-DDTHH:MM:SS" \
  --label 1
```

**Step 6: Train, aggregate, detect:**
```bash
python3 cli.py train-local --data data/live_client1.csv --out models/live_c1.pkl --client-id live_c1
python3 cli.py train-local --data data/live_client2.csv --out models/live_c2.pkl --client-id live_c2
python3 cli.py train-local --data data/live_client3.csv --out models/live_c3.pkl --client-id live_c3
python3 cli.py federated-aggregate --models "models/live_*.pkl" --out models/live_global.pkl
python3 cli.py detect --model models/live_global.pkl --data data/live_client2.csv --top-n 10
```

**Step 7: Evaluate:**
```bash
python3 cli.py evaluate --model models/live_global.pkl --data data/live_client2.csv \
                        --local-models "models/live_c*.pkl" --out results/live/
```

**Step 8: View results:**
```bash
nautilus results/live/
```

**Cleanup after each run:**
```bash
sudo mn -c
```

#### VirtualBox Tips

- Allocate **2 GB RAM minimum** and **2 CPU cores minimum**
- Always use `sudo python3`, not `sudo python`
- If port 6633 is busy: `sudo fuser -k 6633/tcp`
- If Mininet crashes mid-run: `sudo mn -c` before retrying

---

## CLI Reference

| Command | Description |
|---|---|
| `generate-data` | Generate synthetic SDN flow CSVs for N clients |
| `train-local` | Train a local Isolation Forest on one client's data |
| `federated-aggregate` | Aggregate client models into a global ensemble |
| `detect` | Score new SDN flows for anomalies |
| `evaluate` | Compare federated vs local models on labeled test data |
| `simulate-fl` | Run a multi-round FL simulation from a YAML config |

Run `python3 cli.py <command> --help` for full options on any command.

---

## Repository Structure

I use GitHub MCP Server to obtain the Repository Structure:

```text
sdn-poison-guard/
├── .dockerignore
├── .gitignore
├── Dockerfile
├── Makefile
├── README.md
├── cli.py
├── docker-compose.yml
├── environment.yml
├── install.sh
├── requirements.txt
│
├── config/
│   └── fed_config.yaml
│
├── docs/
│   ├── Notes_incl_AI_use.md
│   ├── networkv2.jpg
│   ├── networkv3.jpg
│   ├── ryu_controller.drawio.svg
│   ├── sdn-fl-detector.drawio.svg
│   ├── sdn-poison-guard.drawio.svg
│   ├── sdn_fl_poison.drawio.svg
│   ├── tool2add.drawio.svg
│   └── tool2added.drawio.svg
│
├── scripts/
│   ├── __init__.py
│   └── generate_data.py
│
├── sdn_mininet/
│   ├── __init__.py
│   ├── label_window.py
│   ├── poisoned_host.py
│   ├── ryu_collector.py
│   └── topology.py
│
├── src/
│   ├── __init__.py
│   ├── cli.py
│   ├── detect.py
│   ├── evaluate.py
│   ├── features.py
│   ├── federated.py
│   ├── local_train.py
│   └── sanitizer.py
│
└── tests/
    └── test_sanitizer.py
```

---

### The Core Data & Feature Pipeline

Before any machine learning happens, network traffic has to be captured and turned into numbers a model can understand.
#### scripts/generate_data.py 
This is the first program of my pipeline as it creates data, or fake network logs. This program generates synthetic network flow logs from scratch without relying on the input of external data. It uses statistical rules to make realistic benign traffic along with specific cyber attacks, including DDoS, port scans, and flow table exhaustion. This approach allows the entire machine learning pipeline to be executed, tested, and verified locally without the need to download massive external packet captures. Once generated, these network flow logs are passed into src/features.py for the next stage of the pipeline. In the next stage, raw data is transformed into a structured feature matrix. In a later phase of the project, this synthetic generator will be replaced with the benchmark CICIDS2019 evaluation dataset to test the model's performance on real world attack traffic.

#### src/features.py 

This is the second program in my pipeline. It translates the logs, finds 8 mathematical clues, and groups them into bins. This program takes network traffic logs and organizes them such that a Machine Learning (ML) model can understand them. Instead of looking at raw text or random numbers, the program extracts eight specific details, or mathematical features. The features are consistent, measurable clues like how fast data is moving or how many packets are sent. By looking at the features together, the model can determine if a signature pattern is an attack or normal traffic. The program, for example, measures the speed of the traffic, and calculates ratios like packets-per-second, and evens out the numbers so short and long bursts of data can be compared. It also groups thousands of different connection points into a few organized categories, called bins. As an analogy, this is like sorting mail into specific cubbies based on where it needs to go. Finally, the program translates network languages, such as protocols like TCP and UDP, into simple code numbers. By doing this, the program acts as a translator, turning the complex network activity into a clean, uniform spreadsheet of numbers that the AI security model can easily read and identify cyber attacks.

---

### Local Training vs. Federated Aggregation

The Federated Learning architecture splits the workload between individual local clients and a central coordinator.

#### config/fed_config.yaml 

Before any training begins, this configuration file acts as the master settings panel for the entire Federated Learning simulation. Instead of hardcoding values like the number of clients, training rounds, or aggregation strategy directly into the code, all of those parameters are stored here in a single, human-readable file. This makes the system highly flexible. A researcher can change the number of simulated clients or switch aggregation strategies simply by editing this file. It tells every other program in the pipeline how the federated system should behave.

#### src/local_train.py (The Client Side/trainer)

This is the third program in my pipeline. It is used to train the AI model. This program takes the cleaned-up network clues and uses them to train an AI security model. The model is the Isolation Forest. In Federated Learning, it is directly installed on each individual user's computer. Instead of spending a lot of time studying what normal or safe traffic looks like, an Isolation Forest works like a detective. It hunts for unusual events. It isolates the rare and unusual outlier data and signals it as a cyber attack. Once the local training is finished, the program saves everything together into a neat package, called a bundle. This is merely a newly trained AI model, a data scaler that keeps all the numbers evenly balanced, and a set of local scoring stats used to judge how unusual future traffic might be. This local training process is important for cybersecurity because it protects user privacy. By teaching the AI model directly on the local machine, sensitive network logs never have to be sent over the internet or shared with an outside server.
This is the next program in my pipeline. It is used to train the AI model. This program takes the "cleaned-up" network clues and uses them to train an AI security model. The model is the Isolation Forest. In Federated Learning, it is directly installed on each individual user's computer. Instead of spending a lot of time studying what normal or safe traffic looks like, an Isolation Forest works like a detective. It hunts for unusual events. It isolates the rare and unusual "outlier" data and signals it as a cyber attack.

#### src/federated.py (The Coordinator/Server Side) 

This fourth program in the pipeline acts as a central coordinator that brings together all of the individual AI security models trained in the previous step. It simulates a wholistic environment where multiple computers, or the clients, work together over several rounds to build a master AI security model. The server does not see the private network logs of the clients. To create this unified defense, the program takes the local AI models from all the clients and combines their intelligence using one of two strategies: Score Ensemble acts like a panel of experts averaging out their scores to see how unusual a piece of traffic looks, or Threshold Consensus acts like a democratic vote where the majority must agree before officially declaring the data as a cyber attack. This process is the core of Federated Learning. It creates a massive, network wide protection shield where every participant benefits from the collective knowledge of the entire group. They will be able to spot advanced threats like DDoS attacks together while keeping their own local data completely private and secure.

#### src/sanitizer.py (The Byzantine Guard)

This program is Tool 2's core defense mechanism. Before the central coordinator in src/federated.py computes the global model, the sanitizer intercepts every client's submitted metric and screens it for signs of manipulation. It does this using Z-score filtering, a statistical technique that measures how far each submission deviates from the group average. A client whose anomaly score is dramatically higher or lower than its peers, such as a compromised host submitting inflated values to shift the global model's decision boundary, receives a Z-score that exceeds the configured threshold and is rejected before it can influence aggregation. The sanitizer produces a detailed report naming every accepted and rejected host, their submitted values, and their Z-scores. This makes the poisoning detection auditable and reproducible. Without this guard, a single poisoned client can corrupt the global model for every participant in the federated network.

#### sdn_mininet/poisoned_host.py (The Attacker)

This program simulates the malicious insider that the sanitizer is designed to catch. It runs on host h6 inside the Mininet topology and submits deliberately falsified anomaly score metrics to the Ryu controller's federated learning REST endpoint. The falsification uses a configurable multiplier — set to 100 times the legitimate value by default — to produce a submission that is statistically extreme enough to shift the global model threshold if left undetected. Running this program alongside src/sanitizer.py creates a complete attack and defense demonstration where the poisoning attempt and its interception can be observed in the same experiment.

---

### Detection & Evaluation

Once the global federated model is built, it needs to be put to work and its performance measured.

#### src/detect.py 

This fifth program is the production engine, which means it is the part of the project that actually goes to work protecting the network in real time. Once the master AI model is built by the team of computers, this program uses that collective intelligence to analyze live, new network traffic as it flows by. The program evaluates every connection and automatically tags the data with three specific labels: an anomaly score to measure exactly how suspicious the traffic behaves, an is_anomaly trigger which acts as a yes-or-no alarm button, and an anomaly rank to grade the threat's severity level from low to critical. Overall, this is where the AI stops practicing on fake data and starts to diagnose whether new live traffic is benign or a malignant cyber attack.
    
#### src/evaluate.py 

This sixth program acts as the final report card for the AI pipeline as a whole. It tests the master defense AI model to see how well it performs in the real world. To do this, it calculates standard data science metrics that grade the system's intelligence from different angles: Accuracy for overall correctness, Precision for how trustworthy its alarms are, Recall for its ability to catch every single threat, F1-Score for the balance between precision and recall, and AUC for its overall grading curve. It also shows visual aids including confusion matrices that display whether the AI got it right versus what it misdiagnosed, and performance bar charts. This evaluation shows if the AI is effective. High precision scores mean that the AI will not alert network administrators with false alarms, while a high recall score shows that the system will not miss malignant attacks.
     
---

### SDN Integration with Network Emulation 

The core pipeline can run on synthetic data. The sdn_mininet/ module is used to bridge the gap between simulation and a real SDN environment by using Mininet and a Ryu controller.

#### sdn_mininet/topology.py 

This program builds a virtual, emulated network from scratch using Mininet, a network emulator. It constructs a realistic SDN topology with a controller, three switches, and seven hosts, then links these components together so they can communicate with each other. Each switch represents one federated client organization — s1 serves hosts h1, h2, and the Tool 3 attacker h7, s2 serves hosts h3 and h4, and s3 serves hosts h5 and h6. The program contains built-in traffic generators that simulate both normal user behavior and network attacks, including DDoS floods from h4 and port scans from h6. For Tool 3, the topology also configures a passive OpenFlow listener on switch s1 at port 6654 and starts an HTTP server on h2 at port 80, giving the injector a reachable control-plane entry point and a concrete application-layer target to block.
    
#### sdn_mininet/poisoned_host.py

This program is an addition to Tool 1. It is added such that Tool 2 provides an attack. Host 6 runs this attack as an inside attacker. Instead of loading legitimate parameters from its locally trained model, H6 sends corrupted data, or metrics, to the Ryu controller. The simulted attack will need to be sanitized in order to defend against the attack. While this script is produces an attack, the defense is set up in src/sanitizer.py and sdn_mininet/ryu_collector.py. After the Ryu controller, or ryu_collector.py, receives the data from the hosts, the data is passed to sanitizer.py where the metrics are inspected. If it is poisoned, the metrics are dropped and not added to the FL global model. The sanitized data is then sent to federated.py where it aggregates only verified clean uploads from the honest hosts. 

#### sdn_mininet/ryu_collector.py

This program runs as an application on top of the Ryu SDN controller, or the brain that manages the virtual network's switches. Its job is to act as a data recorder. As traffic flows across the Mininet topology, the Ryu controller continuously receives raw statistics from every switch in the network via the OpenFlow protocol. This program receives those statistics, organizes them into structured rows, and writes them to a CSV file. In short, it is the pipeline's real-time sensor, converting switch data into network flow logs. This is similar to my first phase where scripts/generate_data.py made data synthetically. After Tool 3 injects its DROP rule, the collector continues running normally, but the flow statistics it records for switch s1 will show HTTP traffic from h1 to h2 dropping to zero bytes, capturing the attacker's footprint in the dataset automatically.

#### sdn_mininet/injector.py (The Control-Plane Attacker)

This program is Tool 3's core attack component. While Tools 1 and 2 operate entirely within the machine learning pipeline, this program attacks the SDN network itself at the protocol layer. It operates in two phases. In Phase 1, it uses Scapy to passively sniff the loopback interface for OpenFlow traffic on TCP port 6633, decoding and printing every message header it observes. This demonstrates that the unencrypted control channel is fully readable by any local process, with no special privileges required beyond a raw socket. In Phase 2, it opens a direct TCP connection to the passive OVS listener on switch s1 at port 6654, completes a legitimate-looking OpenFlow 1.3 handshake, requests EQUAL controller role to bypass Ryu's MASTER lock, and sends a crafted OFPT_FLOW_MOD message. That message installs a permanent high-priority rule that drops all TCP port 80 traffic on s1 while leaving ICMP completely unaffected, so pings continue to succeed while HTTP fails. The Ryu controller never detects this rule.

#### sdn_mininet/label_window.py

After a Mininet experiment finishes running, this program acts as a post-processing annotator. Because the traffic generator in topology.py knows when an attack started and stopped, this program takes the raw CSV of collected flows, reviews it, and stamps each time window with the correct label as either benign or the specific attack type that was active during that period. This labeled dataset is what gets forwarded to src/features.py for feature extraction. This finishes the bridge between live SDN emulation and the machine learning pipeline.

---

### Execution, Orchestration & Environment

These files handle the user interface, automation, environment setup, and containerization of the project.

#### cli.py (root entry point) 

This seventh program serves as the main entry point and control center for the user. Instead of forcing you to look through folders and manually run five or six different programs one after the other, this script combines everything into a single, centralized dashboard called a Command-Line Interface (CLI). It allows you to run and manage the entire AI pipeline from your terminal using simple commands. For example, typing python cli.py train automatically wakes up the training programs, while using python cli.py detect activates the production engine to start scanning for cyber attacks. It acts like a universal remote control, making the AI system easy to operate.

#### src/cli.py (argparse command routing) 

While the root cli.py serves as the entry point, this program inside the src/ package handles the detailed tasks behind every command. It uses Python's argparse library to define and validate each sub-command, such as generate, train, detect, and evaluate. It then routes the user's input to the correct module. The root cli.py is the front door and this file is the switchboard operator that ensures requests reach the right program with its arguments.

#### src/init.py 

This file declares the src/ folder as a Python package. Without it, Python would not recognize the folder as a collection of importable modules. In other words, programs like cli.py and federated.py could not reference each other. It holds the package together behind the scenes.

#### Makefile 

This eighth file acts as an automation shortcut. I do the commands in my video, one by one, but this allows you not to do that. The seqeuence: first invents the fake data, next translates it into clean mathematical clues, then training the local AI guards, aggregating them into a consolidated federated model, and finally evaluates the system. In short, it is a script that handles all the heavy lifting, allowing you to test, run, and verify the entire cybersecurity system without entering any commands.

#### install.sh 

This shell script is a one-time setup assistant designed specifically for Ubuntu 20.04 VMs. When run on a fresh system, it automatically installs all of the necessary system-level software dependencies, such as Python, Mininet, and the Ryu controller. Pip or conda cannot install these on their own. It prepares the host machine's operating system before any Python environment is created. It also installs scapy system-wide using sudo pip3 so that Tool 3's injector can open raw sockets, which require root-level package access.

 #### requirements.txt

This standard Python file lists every third party library the project depends on, along with the required versions. When setting up the project in a plain Python virtual environment, running pip install -r requirements.txt reads this list and automatically downloads and installs every dependency in one step. It guarantees that running the project uses the same library versions. Tool 3 adds scapy==2.5.0 to this file, pinned to that specific version to avoid compatibility errors with Python 3.8's cryptography library on Ubuntu 20.04.

#### environment.yml

This file serves the same purpose as requirements.txt but for users who prefer Conda as their package manager. Running conda env create -f environment.yml builds a fully isolated Conda environment with all the correct dependencies pre-configured. It is particularly useful for researchers and data scientists who rely on Conda to manage complex scientific computing environments.

#### Dockerfile

This file contains the instructions for packaging the entire project into a self-contained Docker image. It tells Docker exactly how to build the environment, which base operating system to use, which packages to install, and which files to copy in, so the project can run identically on any machine. Note that Tool 3's injector cannot run inside Docker because it requires a live Open vSwitch instance and raw socket access to the host network, neither of which are available inside a container. Tool 3 requires Ubuntu 20.04 natively.

#### docker-compose.yml

This file orchestrates multi-container deployments of the project. Rather than starting Docker containers one by one with individual commands, docker-compose.yml defines all the services the project needs, such as the training client and the federated coordinator. It then launches them together with a single docker compose up command. It also handles the networking between containers, making it straightforward to simulate multiple federated clients running simultaneously on one machine.

#### .dockerignore

This configuration file tells Docker which files and folders to exclude when building the image, such as the data/, models/, and results/ directories that are generated at runtime. By excluding these files, the Docker image remains robust.

#### .gitignore

This file tells Git which files and folders to leave out of version control. For this project, it excludes the three generated runtime directories, data/, models/, and results/. Their contents are re-creatable by simply running the pipeline and would increase the repository unnecessarily. It also excludes Python cache folders, compiled bytecode files, and local environment folders created by pip or Conda.

---

### Generated Data Directories

These three folders are not committed to the repository and are created automatically when the pipeline runs.

#### data/

This folder is the pipeline's working scratchpad. It stores the synthetic network flow logs produced by scripts/generate_data.py, or the real flow logs captured by sdn_mininet/ryu_collector.py. It also stores the labeled and feature-extracted datasets produced by downstream stages. The data is re-generatable, so it is listed in .gitignore.

#### models/

After each round of local or federated training, the trained model bundles,  including the Isolation Forest model, the data scaler, and the local scoring statistics are saved here. This allows the detection engine in src/detect.py to load a pre-trained model without needing to re-run the full training pipeline. Like the data/ folder, it is git-ignored since models can be reproduced.

#### results/

This folder collects and stores all outputs produced by src/evaluate.py, which includes the confusion matrix images, performance bar charts, any saved metric reports, and the per-round sanitizer audit log written by Tool 2's simulation.

---

### Documentation

#### README.md

The documentation guide containing setup instructions, system design overviews, and evaluation metrics to ensure the project is working correctly.

---

## Known Issues and Limitations

Includes Tools 1, 2, and 3. Tool 3 appears at the end.

| Limitation | Notes |
|---|---|
| L2 flows only in live mode | Ryu learning switch installs MAC-based flows; no IP match fields |
| No secure aggregation | No differential privacy or encrypted model exchange |
| Classical ML only | Isolation Forest; no deep autoencoder |
| Offline evaluation | Static CSV logs; not integrated with a live SDN controller |
| Manual attack labeling | Must note timestamp and run label_window.py after the run |
| Python 3.8 compatibility | All files use `from __future__ import annotations` for type hint support |
| FL updates | Local models do not improve; Global model does not update local hosts after aggregation |
| Test rejection | Needs more clients' data; Lower Z threshold to 1.0 in fed_config.yaml |

| Tool 3 Limitations | Notes |
|---|---|
| scapy==2.50 | Resolved issue; newer versions conflict with Python 3.8 |
| Ryu may prevent the EQUAL role | This may be a security issue resolution by Ryu |
| Routine must be strictly followed | System will not work if commands fall out of order |
| Ryu controller setup delays | Must not start Mininet before Ryu |
| Some commands need sudo | I changed commands to sudo |
| Cleanup commands needed for retesting | If this is not done -> unpredictability |

