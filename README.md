# MIRA-EVO

Versão local-first do MIRA-EVO, preparada para execução local e atualização por pasta de rede/ETL.

## Arquitetura atual

- Next.js/React executado localmente.
- SQL Server permanece como banco nesta etapa.
- Ollama pode ser executado localmente em `http://127.0.0.1:11434`.
- Atualizações podem ser lidas de uma pasta UNC ou unidade de rede por `MIRA_UPDATE_PATH`.
- `MIRA_ETL_PATH` e `MIRA_KNOWLEDGE_PATH` já estão reservados para a integração por arquivos/RAG.
- O atualizador valida SHA-256 antes de aplicar um pacote e mantém rollback local.

## Configuração rápida

Copie `.env.example` para `.env` apenas na máquina de execução e ajuste, no mínimo:

```env
MIRA_UPDATE_PATH=\\SERVIDOR\PASTA_ETL\MIRA-EVO\releases
MIRA_AUTO_UPDATE=true
MIRA_ETL_PATH=\\SERVIDOR\PASTA_ETL\MIRA-EVO\etl
MIRA_KNOWLEDGE_PATH=\\SERVIDOR\PASTA_ETL\MIRA-EVO\knowledge
OLLAMA_BASE_URL=http://127.0.0.1:11434
```

Nunca publique o arquivo `.env`.

## Ollama

Download oficial: https://ollama.com/download

## Privacidade

O diretório `dados_iniciais/` deste repositório contém somente fixtures vazias. Dados reais de usuários, serviços, histórico operacional e credenciais não devem ser versionados.

Consulte `LEIA_PASTA_REDE.md` e `documentacao/MANUAL_LOCALHOST.md` para detalhes.
