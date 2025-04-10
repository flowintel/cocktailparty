
![logo-cocktail-party-horizontal-coul](https://github.com/user-attachments/assets/bc59b4be-d3f0-4fda-bb73-fe9a7487f9d2)

The CocktailParty project is an open-source initiative that aims to provide a seamless and user-friendly solution for distributing data streams to end-users through websockets. Its primary goal is to provide users with a straightforward web interface to explore and subscribe to the available streams.

Key Features:

- Stream Distribution: The project focuses on delivering real-time data streams to end-users.
- Web Interface: The user interface allows users to easily navigate and discover the streams they are interested in.
- Stream Subscription: Users can subscribe to their desired streams and receive realtime updates through websockets.
- Stream Creation: Users may create `sinks` in which that can upload streams of data using [realtime-py](https://github.com/flowintel/realtime-py/tree/master), or other [phoenix channels libraries](https://hexdocs.pm/phoenix/channels.html#client-libraries), or directly by interacting with the websocket following the [phoenix channels spec](https://hexdocs.pm/phoenix/writing_a_channels_client.html).
  
# Moving parts

Cocktailparty leverages the [phoenix framework](https://www.phoenixframework.org/) and the [BEAM virtual machine](https://www.erlang.org/blog/a-brief-beam-primer/) capabilities to provide:
- Connection to different sources (redis/valkey/kvrocks, STOMP, or websocket) and the publishing of their content into phoenix channels, that are then displayed as *sources* to the end user.
- Ability to query the certificate transparency logs through [calidog's certstream-server](https://certstream.calidog.io).
- A pubsub system based on [pg2](https://www.erlang.org/docs/18/man/pg2.html) to route redis topics' content to channels.
- A web interface for managing users, and for users to list sources and sinks, and get access instructions.
That's it.

# Local installation and requirements
## requirements
- a working postgresql instance with a database
- to provide sinks, a working redis-compatilbe server in which data are pushed in pubsub topics.

## compiling from source
```
git clone https://github.com/flowintel/cocktailparty.git
cd cocktailparty
mix deps.get
mix compile
cd assets
npm install 
mix phx.server
```

This will bring up the phx server with default parameters found in `config`.
Parameters customization is done through environmemts variables as listing in `script/launch.sh`:

```bash
#!/bin/bash
# SECRET_KEY_BASE is created using `mix phx.gen.secret`
export SECRET_KEY_BASE=
# use whatever is your IP
export DATABASE_URL=ecto://cocktailparty:mysuperpassword@192.168.1.1/cocktailparty
# Your domain name
export PHX_HOST=broker.d4-project.org
# Is it standalone?
export STANDALONE=false
# Shall this node connect to upstream connection?
export BROKER=false
# The cloak key for encryption at rest
export CLOAK_KEY=
# after mix compile:
# mix phx.server
# or for a running a release:
#./cocktailparty/bin/server
```
## creating a release
Execute `script/release.sh` from the root.

# Deployment
Cocktailparty is meant to be deployed behind a proxy. Nodes' duties can be separated beteween broker nodes and nodes serving clients requests.

## Common deployment
- Apache terminates https
- Apache load balance between a set of phoenix nodes
- Clustering is done through [libcluster](https://hex.pm/packages/libcluster) (gossip protocol by default)

```mermaid
flowchart LR
    A[Apache]
    C{Round Robin}
    A --> C
    R[Redis 1]
    S[Redis 2]
    T[Redis 3]
    
    U(Users)
    U--https-->A
    
    subgraph pg2
        E[HTTP/WS]
        F[HTTP/WS]
        B[Broker]
    end
    
    B --subscribes to-->R
    B --subscribes to-->S
    B --pushes into-->T
    
    C --http--> E
    C --http--> F
```

## Behind apache
Here is an example of an apache config for one broker node, and 2 nodes serving http/websockets:

```
<VirtualHost *:443>
        ServerAdmin toto@example.com

        ErrorLog ${APACHE_LOG_DIR}/error_broker.log
        CustomLog ${APACHE_LOG_DIR}/access_broker.log combined

        ServerName broker.example.com

        ProxyPreserveHost On

        <Proxy "balancer://http">
                BalancerMember "http://10.144.201.48:4000"
                BalancerMember "http://10.144.201.249:4000"
        </Proxy>

        <Proxy balancer://ws>
                BalancerMember "ws://10.144.201.48:4000"
                BalancerMember "ws://10.144.201.249:4000"
        </Proxy>

        RewriteEngine on
        RewriteCond %{HTTP:Upgrade} websocket [NC]
        RewriteCond %{HTTP:Connection} upgrade [NC]
        RewriteRule /(.*) balancer://ws/$1 [P,L]

        RewriteRule ^/(.*)$ balancer://http/$1 [P,QSA,L]
        ProxyPassReverse / balancer://http/

        Include /etc/letsencrypt/options-ssl-apache.conf
        SSLCertificateFile /etc/letsencrypt/live/broker.example.com/fullchain.pem
        SSLCertificateKeyFile /etc/letsencrypt/live/broker.example.com/privkey.pem
</VirtualHost>

```

# Contribution

## License
        Copyright (C) 2023-2025 CIRCL - Computer Incident Response Center Luxembourg
        Copyright (C) 2023-2025 Jean-Louis Huynen

        This program is free software: you can redistribute it and/or modify
        it under the terms of the GNU Affero General Public License as
        published by the Free Software Foundation, either version 3 of the
        License, or (at your option) any later version.

        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU Affero General Public License for more details.

        You should have received a copy of the GNU Affero General Public License
        along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Acknowledgment

![](./img/cef.png)

The project has been co-funded by CEF-TC-2020-2 - 2020-EU-IA-0260 - JTAN - Joint Threat Analysis Network.
