<?php

namespace Tests\Unit;

use CodeIgniter\Test\CIUnitTestCase;

final class AmbienteDockerTest extends CIUnitTestCase
{
    private array $variaveisOriginais;

    private string|false $hostnameOriginal;

    protected function setUp(): void
    {
        parent::setUp();

        $this->variaveisOriginais = $_ENV;
        $this->hostnameOriginal = getenv('database.default.hostname');
    }

    protected function tearDown(): void
    {
        $_ENV = $this->variaveisOriginais;

        if ($this->hostnameOriginal === false) {
            putenv('database.default.hostname');
        } else {
            putenv('database.default.hostname=' . $this->hostnameOriginal);
        }

        parent::tearDown();
    }

    public function testPriorizaHostnameDoContainerSobreConfiguracaoLocal(): void
    {
        putenv('database.default.hostname=banco_teste');
        $_ENV['database.default.hostname'] = '127.0.0.1';

        require ROOTPATH . 'docker/php/ambiente.php';

        $this->assertSame('banco_teste', $_ENV['database.default.hostname']);
    }

    public function testPreservaConfiguracaoLocalQuandoVariavelNaoExisteNoContainer(): void
    {
        putenv('database.default.hostname');
        $_ENV['database.default.hostname'] = '127.0.0.1';

        require ROOTPATH . 'docker/php/ambiente.php';

        $this->assertSame('127.0.0.1', $_ENV['database.default.hostname']);
    }
}
