# 🏛️ Gov.xp — Portal de Serviços Digitais (LB-Phone)

O **Gov.xp** é um ecossistema governamental completo desenvolvido para o framework **LB-Phone**. Ele transforma a experiência do cidadão no servidor, permitindo o acesso a documentos digitais, gestão de patrimônio (veículos e imóveis) e registro de ocorrências policiais em tempo real, tudo integrado à base vRP.

## ✨ Funcionalidades Principais

* **🪪 Carteira Digital**: Exibição de RG, CNH, Carteira Funcional (Polícia Civil) e Porte de Arma com assinaturas e fotos dinâmicas.
* **✈️ Integração ANAC**: Sincronização automática com scripts de aviação para exibir o Brevê de Piloto, horas de voo e reputação.
* **🚗 Gestão de Veículos**:
    * Consulta de IPVA (com aviso de atraso).
    * Exibição do CRLV Digital oficial.
    * **Sistema de Queixa**: Registro e baixa de boletins de roubo/furto com timer de aprovação de 5 segundos.
* **🏠 Gestão de Imóveis**: Visualização de IPTU e Certidão de Registro (Escritura) de casas e apartamentos.
* **📡 Sincronização Global**: Atualiza instantaneamente o `GlobalState.StolenPlates`, permitindo que radares identifiquem veículos roubados na hora.
* **🔐 Segurança**: Sistema de primeiro acesso onde o cidadão cria sua própria senha gov.xp.

## 📦 Dependências

Este script requer os seguintes recursos para funcionar corretamente:

1.  **[LB-Phone](https://github.com/lb-phone)** (Interface base).
2.  **vRP** (Framework do servidor).
3.  **[GrK Radar](LINK_DO_REPOSITORIO_AQUI)** (Necessário para a leitura automática de placas com queixa).

## 🚀 Instalação

1.  Crie uma pasta chamada `gov_xp` no seu diretório de `resources`.
2.  Insira os arquivos e a pasta `web` (HTML/JS/CSS) dentro dela.
3.  **Banco de Dados**: O script utiliza `vRP.Prepare`, então ele criará as tabelas `gov_stolen` e `gov_accounts` automaticamente ao iniciar.
4.  Certifique-se de possuir a tabela `aviacao_pilotos` caso queira utilizar a integração com o Brevê.
5.  Adicione `ensure gov_xp` ao seu arquivo `server.cfg`.

## ⚙️ Integração Técnica (Radar)

O Gov.xp utiliza o **GlobalState** para garantir que a lista de veículos roubados seja acessível por qualquer script do servidor sem necessidade de consultas constantes ao banco de dados.

Para integrar o seu radar, basta verificar a tabela global:
```lua
-- Exemplo de verificação no seu script de radar
local plates = GlobalState.StolenPlates
if plates[placa_detectada] then
    -- Acionar alerta de veículo roubado
end
🎮 Comandos e Uso
Login: No primeiro acesso, o ID do jogador é detectado automaticamente, sendo necessário apenas definir uma senha.

Boletins: Ao reportar um roubo, o sistema simula um protocolo de processamento de 5 segundos antes de homologar a queixa e atualizar o radar global.

🛠️ Desenvolvido por GrK Development • Inovação para o seu Servidor
