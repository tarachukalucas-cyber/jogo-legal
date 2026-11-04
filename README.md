# Ilha Viva — Survival Mobile

Projeto original de sobrevivência 3D para Android, feito em Godot 4.

## Escopo inicial
- Exploração em ilha procedural low-poly
- Ciclo de dia/noite
- Fome, sede e energia
- Coleta de madeira, pedra e frutas
- Inventário e criação de itens
- Construção de abrigo simples
- Controles por toque
- Multiplayer experimental por ENet (host/join)

O projeto é original e não copia código ou recursos de terceiros. Inspira-se no gênero de sobrevivência em mundo aberto.

## Abrir
1. Instale Godot 4.4 ou superior.
2. Abra `project.godot`.
3. Execute a cena principal.

## Android
O workflow `.github/workflows/android.yml` prepara uma exportação Android quando as credenciais e templates de exportação estiverem configurados. Um APK só será disponibilizado após uma execução bem-sucedida do workflow.

## Multiplayer
Na primeira versão, o multiplayer usa conexão direta ENet. Para jogar pela internet, o host precisa estar acessível pela rede; não há ainda servidor público dedicado nem matchmaking.

## Licença
MIT para o código deste projeto.
