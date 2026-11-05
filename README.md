# Ilha Viva — protótipo survival 3D (Godot 4.7.2)

Projeto para PC e Android. O mundo é gerado proceduralmente em chunks de 64 m; chunks próximos do jogador são carregados e os distantes são liberados. O mapa pode se expandir conforme a exploração.

## Sistemas implementados no protótipo
- Câmera em terceira pessoa com rotação pelo botão direito/mouse no PC e arrasto no lado direito da tela touch.
- Personagem humanoide low-poly montado com primitivas 3D.
- Geração procedural por chunks com árvores, pedras e plantas.
- Recursos coletados gravados em `user://ilha_viva_world_v2.json`; árvores/recursos coletados não reaparecem naquele save.
- Relógio de mundo, dia/noite e quatro estações; clima variável com chuva, neblina e tempestade visual.
- Partículas de chuva e neblina ambiental.
- Zumbis investigam locais de ruídos de coleta/construção quando estão dentro do alcance.
- Controles PC e joystick virtual no Android.
- ENet com envio de posições e avatares remotos simples (multiplayer ainda experimental).

## Controles
PC: WASD movimenta; botão direito + mouse gira câmera; E coleta; F come; G bebe; C craft; B constrói; Espaço ação de combate arcade.
Android: joystick esquerdo movimenta; arraste no lado direito para girar a câmera; botões na interface executam ações.

## Abrir no Godot
1. Instale Godot 4.7.2 Standard.
2. Baixe o repositório em **Code > Download ZIP**.
3. Extraia e abra `project.godot`.
4. Execute com F6/F5.

## Builds
GitHub Actions exporta Windows, Linux e Android. Abra a aba **Actions**, selecione a execução mais recente e baixe o arquivo em **Artifacts** depois de uma execução concluída com sucesso.

## Limitações importantes
Este é um protótipo em evolução, não um MMO pronto. A sincronização de jogadores é básica e ainda não há autoridade completa do servidor sobre inventários, coleta, estruturas, zumbis, clima, salvamento compartilhado ou guildas. O estado de recursos é salvo localmente por instalação, não compartilhado entre clientes. Servidor 24/7 exige VPS/servidor dedicado sempre ligado; GitHub Actions apenas compila.
