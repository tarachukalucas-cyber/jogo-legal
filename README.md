# Ilha Viva — Survival para PC e Android

Protótipo original de sobrevivência 3D para computador e celular.

## Controles

### PC
- WASD: movimentar
- E: coletar recursos
- F: comer
- G: beber
- C: craft
- B: construir parede
- Espaço: atacar zumbi
- Também é possível usar os botões da interface com o mouse.

### Celular
- Joystick virtual: movimentar
- Botões na tela: coletar, comer, beber, craft, construir e atacar

## Sistemas no protótipo
- Personagem humanoide low-poly.
- Fome, sede, vida e energia.
- Coleta de madeira, pedra e alimentos.
- Receita inicial e construção de paredes.
- Zumbis que perseguem o jogador.
- Ciclo visual de dia/noite.
- Conexão ENet experimental e criação local de guilda.

## Limitações conhecidas
O multiplayer ainda é experimental: não há sincronização completa de jogadores, zumbis, PvP, guildas compartilhadas ou persistência completa. Não é um MMO pronto para produção. Servidor 24/7 exige uma máquina/VPS sempre ligada; GitHub Actions apenas compila os arquivos.

## Abrir no Godot
1. Instale Godot 4.4.1.
2. Baixe o código pelo botão **Code > Download ZIP** deste repositório.
3. Extraia o ZIP e abra `project.godot` no Godot.
4. Pressione F6/F5 para executar.

## Builds para testar
O workflow **Build PC and Android** gera os artefatos Windows, Linux e Android. Após uma execução bem-sucedida, abra a execução em **Actions** e baixe o artefato correspondente em **Artifacts**.
