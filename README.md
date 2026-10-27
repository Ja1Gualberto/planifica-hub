# planifica-hub
PlanIFica Hub

## Autenticação com CodeIgniter Shield

O projeto utiliza o Shield `^1.4`, instalado via Composer. A configuração segue a
[documentação oficial](https://shield.codeigniter.com/latest/getting_started/install/).

### Instalação local

Requisitos: PHP 8.2 ou superior, Composer e MySQL com suporte a InnoDB.
As verificações e os testes também precisam da extensão `sqlite3` do PHP.

1. Execute `composer install` para instalar as versões do `composer.lock`.
2. Caso ainda não exista um `.env` local, copie `.env.example` para `.env`.
3. Configure nesse arquivo a URL da aplicação e a conexão com um banco MySQL
   **local**, criado previamente. Não versione nem compartilhe as credenciais.
4. Execute `php spark migrate --all`. O comando aplica as migrations oficiais
   do Shield e do pacote Settings, descobertas em `vendor/`.
5. Execute `php spark serve` e acesse `http://localhost:8080/index.php/login`.
   Se configurar outra URL ou remover `index.php`, ajuste o endereço.

O setup já está versionado em `app/Config/Auth.php`, `AuthGroups.php`,
`AuthToken.php`, `Autoload.php`, `Security.php` e `Routes.php`.
Não é necessário executar novamente `php spark shield:setup`.
Os nomes e tipos exigidos pelo pacote são mantidos para compatibilidade,
incluindo suas tabelas, entidades e configurações.

### Fluxos disponíveis

- `GET /register` e `POST /register`: formulário e cadastro de usuário.
- `GET /login` e `POST /login`: formulário e autenticação por e-mail e senha.
- `POST /logout`: encerramento da sessão. Envie o token CSRF em um formulário
  com `csrf_field()`; `GET /logout` não é permitido.

O CSRF é global e utiliza sessão (manual 11.3). As telas e os Controllers são
fornecidos pelo próprio Shield. A página inicial exige autenticação pelo filtro `session`;
futuras rotas restritas devem utilizar os Filters de autenticação e autorização.
Links mágicos e outros fluxos por e-mail exigem configurar o remetente e o
transporte de e-mail no `.env` antes de utilizá-los.

### Verificações no Windows

```powershell
.\vendor\bin\phpcs.bat
php .\vendor\bin\phpstan analyse --no-progress --memory-limit=1G
.\vendor\bin\phpunit
```

O comando direto do PHPUnit gera relatórios de cobertura e precisa de Xdebug
ou PCOV habilitado no PHP da linha de comando. Para executar a mesma suíte
sem cobertura, use `composer test`, já configurado no projeto.

Os testes de autenticação usam SQLite em memória, com migrations dos pacotes,
sem acessar o MySQL da aplicação ou serviços externos. Cobrem cadastro,
hash de senha, login válido e inválido, logout e proteção CSRF.

Após configurar o MySQL local, confira no navegador: cadastro válido e inválido,
login com senha correta e incorreta, logout por formulário POST e nova tentativa
de acesso após sair (manual 16.1). Ao criar páginas restritas, teste também o
acesso direto sem autenticação e com perfis sem permissão.

## Desenvolvimento local com Docker

Este ambiente é exclusivo para desenvolvimento, não para homologação ou produção.
Ele fornece PHP 8.3 com Apache, Composer, MySQL 8.4, phpMyAdmin 5.2.3, SQLite e PCOV.
Não é necessário instalar PHP, Composer ou MySQL no computador. No Windows, use Docker Desktop com
containers Linux e Docker Compose; os comandos abaixo também funcionam no PowerShell.

### Configuração e primeira execução

1. Caso ainda não exista um `.env`, copie o exemplo. No PowerShell:

   ```powershell
   Copy-Item .env.example .env
   ```

   No Linux, use `cp .env.example .env`. Não sobrescreva um `.env` existente.
   Se já tiver um, acrescente somente as variáveis `DOCKER_BANCO_*` presentes no exemplo.

2. No `.env` local, configure `DOCKER_BANCO_NOME` e `DOCKER_BANCO_USUARIO` e preencha
   `DOCKER_BANCO_SENHA` e `DOCKER_BANCO_SENHA_ROOT` com senhas locais distintas e não
   vazias. Não use `root` como usuário da aplicação. Para senhas com `$`, use aspas
   simples no `.env` para evitar interpolação pelo Compose. Não compartilhe esse arquivo.

   O Compose configura a conexão `database.default.*` da aplicação com esses mesmos
   valores e o hostname `banco`, pela rede interna. Essas variáveis de ambiente têm
   precedência sobre os valores do `.env` lidos pelo CodeIgniter. Assim, a configuração
   de banco usada fora do Docker pode ser mantida. O `.env` também é montado somente
   para leitura, para outras configurações locais, como e-mail.

3. Construa a imagem e inicie os serviços:

   ```powershell
   docker compose up -d --build --wait
   ```

   O Compose aguarda o MySQL aceitar uma consulta com o usuário da aplicação antes
   de iniciar a aplicação e o phpMyAdmin. O banco não publica uma porta no computador;
   a aplicação fica disponível apenas na interface local, na porta 8080, e o
   phpMyAdmin na porta 8082.

4. Prepare as dependências do volume e aplique as migrations no banco Docker local:

   ```powershell
   docker compose exec app composer install --no-interaction --prefer-dist
   docker compose exec --user www-data app php spark migrate --all
   ```

   A imagem já instala o `composer.lock`, incluindo as ferramentas de desenvolvimento.
   A instalação explícita mantém o volume `vendor/` sincronizado, inclusive quando
   ele já existe de uma execução anterior. Não execute `shield:setup` novamente.
   As migrations não são executadas automaticamente na construção ou inicialização.

5. Acesse `http://localhost:8080/index.php/login`. O Apache substitui
   `php spark serve`; não inicie os dois na mesma porta. O Compose define
   `CI_ENVIRONMENT=development` e `app.baseURL=http://localhost:8080/` dentro do container.

### Administração local com phpMyAdmin

O phpMyAdmin é um serviço separado no `compose.yaml`, usando a imagem oficial
`phpmyadmin:5.2.3-apache`. O `Dockerfile` permanece exclusivo da aplicação.
Ele inicia junto com `docker compose up -d --build --wait` ou `./planifica dev`.

Acesse `http://localhost:8082` e entre com o usuário definido em
`DOCKER_BANCO_USUARIO` e a senha de `DOCKER_BANCO_SENHA` do seu `.env` local.
O servidor `banco:3306` já está configurado; não há login automático nem cópia
dessas credenciais para o ambiente do phpMyAdmin. Prefira o usuário da aplicação,
não `root`, e não compartilhe suas credenciais.

O acesso é publicado somente em `127.0.0.1`, sem exposição à rede externa
(manual 11.8). Não use este ambiente para acessar bancos de homologação ou produção.
Alterações de estrutura continuam exigindo migrations, mesmo ao usar phpMyAdmin
localmente (manual 8.5). Não versione exportações com dados reais (manual 8.7).

Para iniciar apenas o phpMyAdmin e sua dependência MySQL:

```bash
./planifica phpmyadmin
# Sem o wrapper (também no PowerShell):
docker compose up -d --wait phpmyadmin
```

A porta 8082 evita conflito com o outro projeto local que já utiliza a 8081.
Se a 8082 também estiver em uso, ajuste o mapeamento no `compose.yaml` e os
endereços no wrapper e nesta documentação; não pare serviços de outros projetos.

### Wrapper para Linux

No Linux, use `./planifica` (Bash e Docker Compose v2) para executar os comandos
do ambiente acima. Configure primeiro o `.env`, conforme os passos 1 e 2; o wrapper
não imprime suas credenciais e não sobrescreve esse arquivo.
Use somente com Docker local, nunca com contextos de homologação ou produção.

```bash
./planifica dev                       # build + serviços em background
./planifica setup                     # sincroniza o volume vendor com composer.lock
./planifica spark migrate --all        # migrations explícitas no banco Docker local
./planifica help                      # lista todos os comandos
```

A aplicação continua em `http://localhost:8080/index.php/login`. Execute o arquivo
pelo caminho até ele; não é necessário instalar um comando global. O wrapper fixa
o diretório e o arquivo Compose do projeto, mesmo quando chamado de outra pasta.
No Windows, mantenha os comandos `docker compose` documentados nesta seção.

| Comando | Função |
|---|---|
| `dev`, `stop`, `down` | Iniciar, parar ou remover containers; `down` preserva os volumes |
| `restart [serviço]` | Reiniciar `app` (padrão), `banco` ou `phpmyadmin` |
| `build`, `status` | Reconstruir a imagem da aplicação ou listar todos os serviços |
| `logs [serviço] [opções]` | Acompanhar logs de `app` (padrão), `banco` ou `phpmyadmin` |
| `phpmyadmin` | Iniciar phpMyAdmin e banco, exibindo `http://localhost:8082` |
| `spark [args]`, `php [args]` | Executar a CLI do CodeIgniter ou o PHP |
| `composer [args]`, `setup` | Executar Composer ou instalar dependências com `composer install` |
| `phpcs [args]`, `phpcbf [args]` | Verificar PSR-12 ou corrigir automaticamente o estilo |
| `phpstan [args]` | Executar `phpstan analyse --no-progress --memory-limit=1G` |
| `test [args]` | Executar PHPUnit com cobertura; para dispensá-la, use `test --no-coverage` |
| `check` | Executar PHPCBF, PHPCS e PHPStan, interrompendo em caso de falha |
| `shell`, `exec <cmd> [args]` | Abrir Bash ou executar um comando na aplicação |

```bash
./planifica logs --tail=100
./planifica logs phpmyadmin --tail=100
./planifica logs banco --tail=50
./planifica restart phpmyadmin
./planifica spark routes
./planifica composer test
./planifica php -v
./planifica exec ls -la public
./planifica check
./planifica test
./planifica down
```

Após qualquer alteração PHP, execute `check` e `test` (manual 10.2 e 16.1.7).
`check` e `phpcbf` **podem modificar arquivos PHP**: revise o diff antes do commit.
O retorno 1 do PHPCBF significa correções concluídas e é tratado como sucesso;
falhas de correção interrompem o fluxo. `check` não substitui os testes PHPUnit.

Os comandos da aplicação e as verificações rodam como `www-data`, evitando caches
e logs sem permissão para o Apache. O PHPCBF usa o UID/GID do usuário Linux para
editar os arquivos montados sem torná-los propriedade de root. O Composer usa root
para gerenciar o volume `vendor/`, como na instalação direta acima. Sem terminal
interativo, o wrapper desativa o TTY automaticamente e preserva os argumentos e
códigos de saída das ferramentas, exceto o retorno 1 de sucesso do PHPCBF.

Não foram incluídos `artisan`, `tinker` nem geração de `APP_KEY`, pois são comandos
ou etapas do Laravel. Aqui se usa `spark`. `cs-fixer` foi substituído pelas ferramentas
PHPCBF/PHPCS já adotadas pelo projeto. `npm` e `npx` também não foram incluídos:
não há `package.json` nem Node.js na imagem atual. `setup` não sobe containers nem
executa migrations; primeiro rode `dev`.

`restart` aceita um serviço opcional; em `logs`, informe o serviço antes das opções.
Os demais comandos de ciclo de vida não aceitam argumentos adicionais; em particular,
`./planifica down -v` é recusado para evitar apagar o banco local por engano.
Os demais comandos que aceitam argumentos os repassam à ferramenta correspondente,
sem interpretar strings como código de shell. Para encerrar os logs, use `Ctrl+C`.

Para testar o wrapper isoladamente, sem Docker, PHP ou banco:

```bash
bash tests/scripts/planifica_test.sh
```

### Verificações dentro do container

Mesmo no PowerShell, os executáveis dentro do container são Linux: use `/` e não
adicione `.bat`. Execute as verificações com o mesmo usuário do Apache, evitando
arquivos de cache e log sem permissão de escrita para a aplicação:

```powershell
docker compose exec --user www-data app vendor/bin/phpcs
docker compose exec --user www-data app vendor/bin/phpstan analyse --no-progress --memory-limit=1G
docker compose exec --user www-data app vendor/bin/phpunit
```

O PCOV está habilitado para cobertura de `app/`. Para rodar a suíte sem cobertura:

```powershell
docker compose exec --user www-data app composer test
```

Os testes continuam usando SQLite em memória, sem depender dos dados do MySQL.
Os relatórios ficam em `/var/www/html/build/logs`, em um volume separado. Para
copiá-los para o computador:

```powershell
docker compose cp app:/var/www/html/build/. ./build
```

Confira também no navegador cadastro válido e inválido, login correto e incorreto,
logout por POST e bloqueio da página inicial após sair, como descrito acima.

### Arquivos, volumes e manutenção

- `Dockerfile`: instala extensões, Composer e dependências; serve somente `public/`.
- `.dockerignore`: impede que `.env`, dependências locais e dados de execução entrem
  na imagem (manual 10.5 e 11.8).
- `docker/php/desenvolvimento.ini`: configura memória e cobertura com PCOV.
- O entrypoint usa Bash e `docker/php/ambiente.php` importa as variáveis com pontos
  em `$_ENV` antes da aplicação, para dar precedência aos valores do container.
- `compose.yaml`: conecta aplicação, banco e phpMyAdmin, sem credenciais fixas no código.
- O código é montado do computador: as edições aparecem sem reconstruir a imagem.
  Dependências, `writable/` e `build/` usam volumes próprios, sem reutilizar arquivos
  do Windows. Por isso, os logs e as sessões Docker não aparecem no `writable/` local.
- Se `composer.lock` mudar, execute novamente o `composer install` acima. Se o
  Dockerfile ou o INI mudar, execute novamente `docker compose up -d --build --wait`.
- Alterar senhas ou o nome do banco no `.env` não reconfigura um volume MySQL já
  inicializado. Mantenha os valores usados na criação ou faça uma alteração local
  controlada das credenciais; não apague volumes para tentar corrigir isso.
- Não publique a saída completa de `docker compose config`, pois pode conter senhas.

Para parar e remover os containers, preservando banco, sessões e dependências:

```powershell
docker compose down
```

**Não acrescente `--volumes` ou `-v`**: isso apagaria os volumes, incluindo o banco local.
