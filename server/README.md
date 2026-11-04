# Servidor dedicado 24/7 — Ilha Viva

## Requisitos
Para manter o mundo online 24 horas, o processo deve rodar em VPS Linux ou servidor dedicado. GitHub Actions não é hospedagem e encerra após compilar.

Configuração sugerida para teste: Ubuntu 22.04/24.04 x86_64, 2 vCPU, 2–4 GB RAM, UDP 24517 liberada, systemd e backups.

## Inicialização
Instale Godot 4.4.1 no servidor e execute na pasta do projeto:

    godot --headless --path . -- --server

O processo tenta abrir ENet na porta UDP 24517. Libere UDP no firewall do provedor e do sistema.

## Serviço systemd
Crie /etc/systemd/system/ilha-viva.service:

    [Unit]
    Description=Ilha Viva Dedicated Server
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=simple
    User=ilha-viva
    WorkingDirectory=/opt/ilha-viva
    ExecStart=/usr/local/bin/godot --headless --path /opt/ilha-viva -- --server
    Restart=always
    RestartSec=5
    NoNewPrivileges=true

    [Install]
    WantedBy=multi-user.target

Ative com:

    sudo systemctl daemon-reload
    sudo systemctl enable --now ilha-viva
    sudo systemctl status ilha-viva

## Limitações atuais
A inicialização dedicada e a conexão ENet são experimentais. O servidor ainda não implementa simulação autoritativa completa, salvamento confiável de todo o estado, replicação de zumbis/estruturas, PvP validado, guildas compartilhadas nem proteção contra trapaças. Não anunciar como servidor público pronto até esses módulos serem desenvolvidos e testados com vários clientes.
