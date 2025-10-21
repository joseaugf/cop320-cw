# Scripts Directory

Scripts essenciais para deployment e validação automatizados.

## 🚀 Deployment Scripts

### `full-deploy.sh`
**Deployment completo local**

```bash
chmod +x scripts/full-deploy.sh
./scripts/full-deploy.sh
```

Faz deployment de tudo:
- Infraestrutura (CloudFormation)
- Build e push de imagens
- Deploy no Kubernetes
- Configuração de observabilidade

**Tempo**: 30-45 minutos

### `generate-k8s-manifests.py`
**Gera manifestos do Kubernetes com valores corretos**

```bash
python3 scripts/generate-k8s-manifests.py
```

Usado automaticamente pelo buildspec. Substitui placeholders nos manifestos com:
- AWS Account ID
- AWS Region
- ECR image URLs
- Database endpoints
- Senhas do Secrets Manager

**Crítico**: Este script é essencial para o deployment automatizado.

## ✅ Validation Scripts

### `validate-deployment.sh`
**Valida deployment pós-conclusão**

```bash
chmod +x scripts/validate-deployment.sh
./scripts/validate-deployment.sh
```

Executa 19 testes:
- CloudFormation stack
- EKS cluster e nodes
- Pods de todos os serviços
- ALB e endpoints
- Observabilidade (ADOT, dashboards, alarmes)
- Secrets Manager
- ECR repositories

**Resultado**: PASS/FAIL para cada teste

### `verify-files.sh`
**Verifica arquivos críticos antes do push**

```bash
chmod +x scripts/verify-files.sh
./scripts/verify-files.sh
```

Verifica presença de:
- Buildspec
- CloudFormation templates
- Scripts AWS
- Manifestos Kubernetes
- Dockerfiles
- Código de chaos engineering

**Use antes de**: `git push`

## 🔧 Utility Scripts

### `prepare-k8s-templates.sh`
**Prepara templates do Kubernetes (opcional)**

```bash
chmod +x scripts/prepare-k8s-templates.sh
./scripts/prepare-k8s-templates.sh
```

Converte manifestos existentes em templates com placeholders.

**Nota**: Geralmente não é necessário executar manualmente.

## 📋 Ordem de Execução

### Para Deployment Local
```bash
# 1. Verificar arquivos
./scripts/verify-files.sh

# 2. Deploy completo
./scripts/full-deploy.sh

# 3. Validar
./scripts/validate-deployment.sh
```

### Para Deployment via CodeBuild
```bash
# 1. Verificar arquivos
./scripts/verify-files.sh

# 2. Push para GitHub
git push origin main

# 3. Iniciar CodeBuild
aws codebuild start-build --project-name PetshopDemo-FullDeployment

# 4. Após conclusão, validar
./scripts/validate-deployment.sh
```

## 🔒 Permissões

Todos os scripts precisam de permissão de execução:

```bash
chmod +x scripts/*.sh
```

Ou individualmente:
```bash
chmod +x scripts/full-deploy.sh
chmod +x scripts/validate-deployment.sh
chmod +x scripts/verify-files.sh
```

## 📝 Variáveis de Ambiente

Os scripts usam estas variáveis (com defaults):

```bash
export AWS_REGION=us-east-2              # Região AWS
export STACK_NAME=petshop-observability-demo  # Nome do stack
export CLUSTER_NAME=petshop-demo-eks     # Nome do cluster
export NAMESPACE=petshop-demo            # Namespace K8s
```

## 🐛 Troubleshooting

### Script falha com "permission denied"
```bash
chmod +x scripts/<script-name>.sh
```

### Python script falha
```bash
# Instalar dependências
pip install boto3 pyyaml

# Verificar Python version
python3 --version  # Deve ser 3.11+
```

### "AWS credentials not found"
```bash
# Configurar AWS CLI
aws configure

# Ou exportar credenciais
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
```

### "kubectl: command not found"
```bash
# Instalar kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

## 📊 Output

### full-deploy.sh
Cria:
- `deployment-summary.json` - Resumo do deployment
- `k8s-generated/` - Manifestos gerados

### validate-deployment.sh
Mostra:
- ✓ PASS para testes bem-sucedidos
- ✗ FAIL para testes falhados
- Resumo final com contagem

### verify-files.sh
Mostra:
- ✓ para arquivos encontrados
- ✗ para arquivos faltando
- Contagem total

## 🎯 Scripts por Caso de Uso

### Primeiro Deployment
```bash
./scripts/verify-files.sh    # Verificar arquivos
./scripts/full-deploy.sh      # Deploy completo
./scripts/validate-deployment.sh  # Validar
```

### Atualização
```bash
./scripts/full-deploy.sh      # Re-deploy
./scripts/validate-deployment.sh  # Validar
```

### Troubleshooting
```bash
./scripts/validate-deployment.sh  # Identificar problemas
# Revisar logs
kubectl logs -n petshop-demo <pod-name>
```

### Antes de Push
```bash
./scripts/verify-files.sh    # Garantir todos os arquivos
git add .
git commit -m "..."
git push
```

## 📚 Documentação Relacionada

- `../DEPLOYMENT.md` - Guia completo de deployment
- `../QUICKSTART.md` - Início rápido
- `../buildspec-full-deploy.yml` - Buildspec do CodeBuild
- `../aws/AUTOMATED_DEPLOYMENT_GUIDE.md` - Guia detalhado

## ✅ Checklist

Antes de usar os scripts:

- [ ] AWS CLI configurado
- [ ] kubectl instalado
- [ ] Docker instalado (para build local)
- [ ] Python 3.11+ instalado
- [ ] Permissões de execução nos scripts
- [ ] Variáveis de ambiente configuradas (opcional)

## 🎉 Pronto!

Com estes scripts, você pode fazer deployment completo da aplicação de forma automatizada em qualquer conta AWS e região.
