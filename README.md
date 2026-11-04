# Ilha Viva — Survival Mobile

Protótipo original de sobrevivência 3D para Android.

## Identidade visual
- Jogador branco minimalista em formato de feijão/cápsula, sem rosto nem roupas.
- Zumbis low-poly e ilha aberta com árvores, rochas e plantas coletáveis.

## Sistemas no protótipo
- Fome, sede, vida e energia.
- Coleta de madeira, pedra e alimentos próximos.
- Receita inicial: 2 madeiras + 1 pedra = kit de reparo.
- Construção de paredes para iniciar uma base.
- Zumbis que perseguem o jogador e causam dano ao se aproximar.
- Ciclo visual de dia/noite e joystick touch.
- Conexão por IP e modo ENet dedicado experimental.
- Criação local de guilda salva no arquivo de mundo.

## Estado real do multiplayer
O código contém uma base experimental de conexão ENet, mas ainda não é um MMO funcional. PvP sincronizado, guildas compartilhadas entre clientes, inventário autoritativo, persistência completa de jogadores/bases e replicação de zumbis ainda precisam ser implementados e testados. Não use o protótipo como servidor público de produção.

## Servidor 24 horas
Um servidor 24/7 precisa rodar em uma máquina sempre ligada (VPS/servidor dedicado). GitHub Actions compila e armazena artefatos; não mantém o jogo hospedado continuamente. Consulte server/README.md. Porta padrão: UDP 24517.

## Abrir
1. Instale Godot 4.4.1 ou superior.
2. Abra project.godot.
3. Execute a cena principal.

## Android
O preset Android usa ARM64. O APK depende de exportação concluída no GitHub Actions e ainda precisa ser testado em aparelho físico.

## Próximas etapas
1. Servidor dedicado Linux com estado autoritativo e salvamento automático.
2. Sincronização de jogadores, zumbis, itens e construção.
3. PvP com validação de alcance, cooldown e vida no servidor.
4. Guildas persistentes, convites, cargos e proteção de bases.
5. Inventário, receitas, ferramentas e equipamentos.
6. Testes de rede, segurança e desempenho.

Licença MIT para o código original.
