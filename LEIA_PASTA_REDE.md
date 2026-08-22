# Mira-Evo — atualização por pasta local/rede

O Mira-Evo continua instalado e executado localmente. A pasta compartilhada serve como canal de distribuição de versões.

## 1. Aponte o caminho

Depois de executar `instalar.bat`, abra o `.env` da raiz e troque:

```env
MIRA_UPDATE_PATH=\\SERVIDOR\PASTA_ETL\MIRA-EVO\releases
```

pelo caminho real. Também aceita unidade mapeada:

```env
MIRA_UPDATE_PATH=Z:\MIRA-EVO\releases
```

Os caminhos abaixo já ficam reservados para a etapa ETL/RAG:

```env
MIRA_ETL_PATH=\\SERVIDOR\PASTA_ETL\MIRA-EVO\etl
MIRA_KNOWLEDGE_PATH=\\SERVIDOR\PASTA_ETL\MIRA-EVO\knowledge
OLLAMA_BASE_URL=http://127.0.0.1:11434
```

## 2. Estrutura da pasta de atualizações

```text
releases/
├── update-manifest.json
└── miraevo_update.zip
```

Com `MIRA_AUTO_UPDATE=true`, `iniciar.bat` verifica essa pasta antes de iniciar o servidor local.

O atualizador copia o pacote para o disco local, valida SHA-256, cria backup do código, aplica a nova versão, recompila e só então altera `VERSION`. Em caso de falha, restaura o backup.

## 3. Gerar/publicar uma nova versão

No projeto-fonte:

```bash
bash gerar_update_localhost.sh 1.1.0.0 "//servidor/pasta_etl/MIRA-EVO/releases"
```

Isso gera e publica `miraevo_update.zip` + `update-manifest.json`.

## Importante

Nesta entrega, `MIRA_ETL_PATH` e `MIRA_KNOWLEDGE_PATH` são caminhos preparados para integração futura. O banco ainda é SQL Server. Migrar a persistência para SQLite/arquivo local deve ser feito como uma etapa separada para não misturar sincronização de arquivos com transações do sistema.
