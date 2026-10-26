<?php

declare(strict_types=1);

// O DotEnv do CI4 consulta $_ENV antes de getenv() ao carregar a configuração local.
$configuracoes = [
    'app.baseURL',
    'database.default.hostname',
    'database.default.database',
    'database.default.username',
    'database.default.password',
    'database.default.DBDriver',
    'database.default.port',
];

foreach ($configuracoes as $nome) {
    $valor = getenv($nome);

    if ($valor !== false) {
        $_ENV[$nome] = $valor;
    }
}

unset($configuracoes, $nome, $valor);
