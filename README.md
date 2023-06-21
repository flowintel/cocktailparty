# CocktailParty

This project is a work in progress and not feature complete, therefore this readme may not align with reality.

The CocktailParty project is an open-source initiative that aims to provide a seamless and user-friendly solution for distributing data streams to end-users through websockets. Its primary goal is to empower users with a straightforward web interface that enables them to effortlessly explore and subscribe to the available streams.

Key Features:

- Stream Distribution: The project focuses on delivering real-time data streams to end-users.
- Web Interface: The user interface allows users to easily navigate and discover the streams they are interested in.
- Stream Subscription: Users can subscribe to their desired streams and receive realtime updates.
  
# Moving parts

Cocktailparty leverages the [phoenix framework](https://www.phoenixframework.org/) and the [BEAM virtual machine](https://www.erlang.org/blog/a-brief-beam-primer/) capabilities to provide:
- A broker that take data from different sources (At the moment only topics from *one* redis instance) and publish the content into phoenix channels, that are then displayed as *sources* to the end user.
- A pubsub system based on [pg2](https://www.erlang.org/docs/18/man/pg2.html) to route redis topics'c content to channels.
- A web interface for managing users, and for users to create *tokens*, list sources and get access instructions.
That's it.

# Local installation and requirements
## requirements
- a working postgresql instance with a database
- a working redis server in which data are pushed in pubsub topics

## compiling from source
```
git clone https://github.com/flowintel/cocktailparty.git
cd cocktailparty
mix deps.get
mix compile
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
export REDIS_URI=redis://192.168.1.1:6390/0
# Your domain name
export PHX_HOST=broker.d4-project.org
# Is it standalone?
export STANDALONE=false
# Shall we launch the broker?
export BROKER=false
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
- One broker is keeping a connection to a redis server
- Clustering is done through [libcluster](https://hex.pm/packages/libcluster) (gossip protocol by default)

```mermaid
flowchart LR
    A[Apache]
    C{Round Robin}
    A --> C
    R[Redis]
    
    U(Users)
    U--https-->A
    
    subgraph pg2
        E[HTTP/WS]
        F[HTTP/WS]
        B[Broker]
    end
    
    B --subscribe to-->R
    
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
        Copyright (C) 2023 CIRCL - Computer Incident Response Center Luxembourg
        Copyright (C) 2023 Jean-Louis Huynen

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
