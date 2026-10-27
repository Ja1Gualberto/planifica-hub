#!/usr/bin/env bash

set -euo pipefail

diretorioRaiz="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
diretorioTemporario="$(mktemp -d "${TMPDIR:-/tmp}/planifica-testes.XXXXXXXX")"
trap 'rm -rf -- "$diretorioTemporario"' EXIT

diretorioProjeto="$diretorioTemporario/projeto com espacos"
diretorioExecutaveis="$diretorioTemporario/bin"
arquivoChamadas="$diretorioTemporario/chamadas"
arquivoEsperado="$diretorioTemporario/esperado"
arquivoSaida="$diretorioTemporario/saida"
totalTestes=0

mkdir -p "$diretorioProjeto" "$diretorioExecutaveis"
cp "$diretorioRaiz/planifica" "$diretorioProjeto/planifica"
touch "$diretorioProjeto/.env" "$diretorioProjeto/compose.yaml"

# O dublê registra argumentos separados por NUL: espaços e metacaracteres são preservados.
cat > "$diretorioExecutaveis/docker" <<'DOCKER'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == 'compose version' ]]; then
    exit "$PLANIFICA_TESTE_RETORNO_COMPOSE"
fi

printf '%s\0' "$PWD" "$@" >> "$PLANIFICA_TESTE_ARQUIVO"

case " $* " in
    *' vendor/bin/phpcbf '*) exit "$PLANIFICA_TESTE_RETORNO_PHPCBF" ;;
    *' vendor/bin/phpcs '*) exit "$PLANIFICA_TESTE_RETORNO_PHPCS" ;;
    *) exit "$PLANIFICA_TESTE_RETORNO_COMANDO" ;;
esac
DOCKER
chmod +x "$diretorioExecutaveis/docker"

export PLANIFICA_TESTE_ARQUIVO="$arquivoChamadas"
opcoesCompose=(compose --project-directory "$diretorioProjeto"
    --env-file "$diretorioProjeto/.env" --file "$diretorioProjeto/compose.yaml")
opcoesExec=(exec -T --user www-data --env HOME=/tmp app)
opcoesCorrecao=(exec -T --user "$(id -u):$(id -g)" --env HOME=/tmp app)

prepararTeste() {
    : > "$arquivoChamadas"
    : > "$arquivoEsperado"
    export PLANIFICA_TESTE_RETORNO_COMPOSE=0
    export PLANIFICA_TESTE_RETORNO_PHPCBF=0
    export PLANIFICA_TESTE_RETORNO_PHPCS=0
    export PLANIFICA_TESTE_RETORNO_COMANDO=0
}

executarWrapper() {
    codigoSaida=0
    PATH="$diretorioExecutaveis:$PATH" bash "$diretorioProjeto/planifica" "$@" \
        > "$arquivoSaida" 2>&1 || codigoSaida=$?
}

esperarChamada() {
    printf '%s\0' "$diretorioProjeto" "${opcoesCompose[@]}" "$@" >> "$arquivoEsperado"
}

conferirResultado() {
    local codigoEsperado="$1"

    if [[ "$codigoSaida" -ne "$codigoEsperado" ]] || ! cmp -s "$arquivoEsperado" "$arquivoChamadas"; then
        printf 'Falha no caso %s: retorno esperado %s, recebido %s.\n' \
            "$((totalTestes + 1))" "$codigoEsperado" "$codigoSaida" >&2
        cat "$arquivoSaida" >&2
        exit 1
    fi

    totalTestes=$((totalTestes + 1))
}

# Executar fora da raiz e com espaços no caminho não pode trocar o projeto Compose.
cd -- "$diretorioTemporario"

for comando in help -h --help; do
    prepararTeste
    PLANIFICA_TESTE_RETORNO_COMPOSE=1
    executarWrapper "$comando"
    conferirResultado 0
    grep -q 'Uso: ./planifica' "$arquivoSaida"
done

prepararTeste
executarWrapper
conferirResultado 0

prepararTeste
executarWrapper dev
esperarChamada up -d --build --wait
conferirResultado 0
grep -q 'phpMyAdmin: http://localhost:8082' "$arquivoSaida"

prepararTeste
executarWrapper phpmyadmin
esperarChamada up -d --wait phpmyadmin
conferirResultado 0
grep -q 'phpMyAdmin: http://localhost:8082' "$arquivoSaida"

for comando in dev phpmyadmin; do
    prepararTeste
    PLANIFICA_TESTE_RETORNO_COMANDO=23
    executarWrapper "$comando"
    if [[ "$comando" == dev ]]; then
        esperarChamada up -d --build --wait
    else
        esperarChamada up -d --wait phpmyadmin
    fi
    conferirResultado 23
    if grep -q 'phpMyAdmin: http://localhost:8082' "$arquivoSaida"; then
        printf 'O endereço não deve ser anunciado se a inicialização falhar.\n' >&2
        exit 1
    fi
done

for comando in stop down; do
    prepararTeste
    executarWrapper "$comando"
    esperarChamada "$comando"
    conferirResultado 0
done

for comando in restart build; do
    prepararTeste
    executarWrapper "$comando"
    esperarChamada "$comando" app
    conferirResultado 0
done

prepararTeste
executarWrapper status
esperarChamada ps
conferirResultado 0

prepararTeste
executarWrapper logs --tail=25 --since '5 minutes ago'
esperarChamada logs --follow --tail=25 --since '5 minutes ago' app
conferirResultado 0

for servico in app banco phpmyadmin; do
    prepararTeste
    executarWrapper restart "$servico"
    esperarChamada restart "$servico"
    conferirResultado 0

    prepararTeste
    executarWrapper logs "$servico" --tail=25 --since '5 minutes ago'
    esperarChamada logs --follow --tail=25 --since '5 minutes ago' "$servico"
    conferirResultado 0
done

for comando in restart logs; do
    for servico in desconhecido '' 'phpmyadmin; touch arquivo_indesejado'; do
        prepararTeste
        executarWrapper "$comando" "$servico"
        conferirResultado 1
        grep -q 'Serviço inválido' "$arquivoSaida"
    done
done

prepararTeste
executarWrapper restart phpmyadmin banco
conferirResultado 1
grep -q 'não aceita argumentos extras' "$arquivoSaida"

prepararTeste
executarWrapper spark migrate --all
esperarChamada "${opcoesExec[@]}" php spark migrate --all
conferirResultado 0

prepararTeste
executarWrapper composer show --format=json
esperarChamada exec -T --user root --env HOME=/tmp app composer show --format=json
conferirResultado 0

prepararTeste
executarWrapper setup
esperarChamada exec -T --user root --env HOME=/tmp app composer install --no-interaction --prefer-dist
conferirResultado 0

prepararTeste
executarWrapper php -r 'echo "argumento com espacos";'
esperarChamada "${opcoesExec[@]}" php -r 'echo "argumento com espacos";'
conferirResultado 0

for comando in phpcs test; do
    prepararTeste
    executarWrapper "$comando" --help
    ferramenta=phpcs
    [[ "$comando" != test ]] || ferramenta=phpunit
    esperarChamada "${opcoesExec[@]}" "vendor/bin/$ferramenta" --help
    conferirResultado 0
done

prepararTeste
executarWrapper phpstan --level=5
esperarChamada "${opcoesExec[@]}" vendor/bin/phpstan analyse --no-progress --memory-limit=1G --level=5
conferirResultado 0

prepararTeste
executarWrapper shell
esperarChamada "${opcoesExec[@]}" bash
conferirResultado 0

prepararTeste
argumentoLiteral='$(touch arquivo_indesejado); * "teste"'
executarWrapper exec printf '%s' "$argumentoLiteral" ''
esperarChamada "${opcoesExec[@]}" printf '%s' "$argumentoLiteral" ''
conferirResultado 0
[[ ! -e "$diretorioProjeto/arquivo_indesejado" ]]

for retornoCorrecao in 0 1 2 3; do
    prepararTeste
    PLANIFICA_TESTE_RETORNO_PHPCBF="$retornoCorrecao"
    executarWrapper phpcbf 'app/arquivo com espacos.php'
    esperarChamada "${opcoesCorrecao[@]}" vendor/bin/phpcbf 'app/arquivo com espacos.php'
    retornoEsperado="$retornoCorrecao"
    [[ "$retornoCorrecao" -ne 1 ]] || retornoEsperado=0
    conferirResultado "$retornoEsperado"

    prepararTeste
    PLANIFICA_TESTE_RETORNO_PHPCBF="$retornoCorrecao"
    executarWrapper check
    esperarChamada "${opcoesCorrecao[@]}" vendor/bin/phpcbf
    if [[ "$retornoCorrecao" -le 1 ]]; then
        esperarChamada "${opcoesExec[@]}" vendor/bin/phpcs
        esperarChamada "${opcoesExec[@]}" vendor/bin/phpstan analyse --no-progress --memory-limit=1G
    fi
    conferirResultado "$retornoEsperado"
done

prepararTeste
PLANIFICA_TESTE_RETORNO_PHPCS=2
executarWrapper check
esperarChamada "${opcoesCorrecao[@]}" vendor/bin/phpcbf
esperarChamada "${opcoesExec[@]}" vendor/bin/phpcs
conferirResultado 2

prepararTeste
PLANIFICA_TESTE_RETORNO_COMANDO=17
executarWrapper check
esperarChamada "${opcoesCorrecao[@]}" vendor/bin/phpcbf
esperarChamada "${opcoesExec[@]}" vendor/bin/phpcs
esperarChamada "${opcoesExec[@]}" vendor/bin/phpstan analyse --no-progress --memory-limit=1G
conferirResultado 17

prepararTeste
PLANIFICA_TESTE_RETORNO_COMANDO=23
executarWrapper php -v
esperarChamada "${opcoesExec[@]}" php -v
conferirResultado 23

for comando in desconhecido artisan tinker npm npx cs-fixer; do
    prepararTeste
    executarWrapper "$comando"
    conferirResultado 1
    grep -q 'Comando desconhecido' "$arquivoSaida"
done

for comando in dev stop down restart build status check setup shell phpmyadmin; do
    prepararTeste
    executarWrapper "$comando" -v
    conferirResultado 1
    grep -q 'não aceita argumentos extras' "$arquivoSaida"
done

prepararTeste
executarWrapper exec
conferirResultado 1

prepararTeste
executarWrapper exec ''
conferirResultado 1

prepararTeste
PLANIFICA_TESTE_RETORNO_COMPOSE=1
executarWrapper status
conferirResultado 1
grep -q 'Compose v2 não está disponível' "$arquivoSaida"

prepararTeste
rm -- "$diretorioProjeto/.env"
executarWrapper dev
conferirResultado 1
grep -q 'Crie o .env' "$arquivoSaida"

prepararTeste
executarWrapper help
conferirResultado 0
[[ ! -e "$diretorioProjeto/.env" ]]

# Um PATH isolado impede que o teste use o Docker instalado no computador.
diretorioSemDocker="$diretorioTemporario/sem-docker"
mkdir "$diretorioSemDocker"
ln -s "$(command -v dirname)" "$diretorioSemDocker/dirname"
caminhoBash="$(command -v bash)"
prepararTeste
codigoSaida=0
PATH="$diretorioSemDocker" "$caminhoBash" "$diretorioProjeto/planifica" status \
    > "$arquivoSaida" 2>&1 || codigoSaida=$?
conferirResultado 1
grep -q 'Instale o Docker' "$arquivoSaida"

printf '%s testes do wrapper passaram (Docker simulado, sem acesso ao banco).\n' "$totalTestes"
