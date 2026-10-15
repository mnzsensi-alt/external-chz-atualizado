# inject chz — projeto sem API

Esta entrega contém os fontes já preparados da versão sem API, com projeto Xcode, bibliotecas SDK existentes, logo transparente e importador local de `.3105`. Não é necessário executar os scripts antigos de personalização nem baixar o arquivo-fonte original para abrir este projeto.

## Abrir no Xcode

1. Extraia todo o ZIP.
2. Em um Mac, abra `projeto-ios/ThreeOneOSFive.xcodeproj`.
3. Selecione o scheme do aplicativo e um destino iOS compatível.
4. Para instalar diretamente em um aparelho, configure a assinatura e o perfil de provisionamento adequados. O pacote não fornece certificados ou credenciais.

## Compilar sem assinatura

Com Xcode, suas ferramentas de linha de comando e Python 3 disponíveis no Mac, execute na pasta raiz deste pacote:

```bash
bash compilar-macos.sh
```

O resultado será `dist/inject-chz-sem-api.ipa`, sem assinatura. O script usa os mesmos parâmetros principais de archive da compilação validada, adaptados aos caminhos deste ZIP. A assinatura é uma etapa separada e depende dos certificados/perfis disponíveis.

## GitHub Actions

Envie o **conteúdo** desta pasta para a raiz de um repositório seu; não apenas o ZIP e não uma pasta adicional envolvendo os arquivos. O workflow `.github/workflows/ios-inject-chz-sem-api.yml` permite executar o build pela aba Actions ou por push no branch `main`. O artefato resultante é `inject-chz-sem-api`.

O build requer disponibilidade de executor macOS e Xcode no GitHub. O workflow deste pacote foi adaptado para compilar diretamente os fontes já preparados; não reinjeta a API. Sua configuração e sintaxe foram verificadas, mas esse workflow adaptado não foi executado separadamente.

## Estrutura

| Caminho | Conteúdo |
| --- | --- |
| `projeto-ios/ThreeOneOSFive/` | Código SwiftUI, componentes e recursos nativos do aplicativo |
| `projeto-ios/ThreeOneOSFive/ContentView.swift` | Navegação e tela Início em modo local, sem gate de key |
| `projeto-ios/ThreeOneOSFive/App.swift` | Inicialização sem login remoto |
| `projeto-ios/ThreeOneOSFive/views/PatchProjectsView.swift` | Importador e gerenciamento nativo de pacotes locais |
| `projeto-ios/ThreeOneOSFive/Assets.xcassets/InjectCHZLogo.imageset/` | Logo inject chz com transparência |
| `projeto-ios/ThreeOneOSFive/SDK/` | Bibliotecas existentes necessárias à compilação |
| `projeto-ios/ThreeOneOSFive.xcodeproj/` | Projeto Xcode |
| `compilar-macos.sh` | Archive e empacotamento de IPA não assinada |
| `.github/workflows/ios-inject-chz-sem-api.yml` | Recompilação por GitHub Actions |

## Diferenças da versão com API

- Não há login por key, validação de licença nem consulta ao Railway.
- O contador de licença e os catálogos online não fazem parte desta variante.
- A aba Injetor usa o importador local nativo; os cartões de arquivos do catálogo remoto não são incluídos.
- Texturas permanece como seção informativa, com encaminhamento ao Injetor para importar arquivos locais; não baixa texturas da API.
- O logo transparente e o nome inject chz foram preservados.
- Nenhum banco de dados, conta administrativa, token de sessão, certificado, segredo de CI ou histórico `.git` foi incluído.

## Validação e limitações

Os fontes correspondem à versão sem API compilada com sucesso na execução `38804447581`, a partir do commit `220e67f859e2fd3ae66da20e93757ce42fe0dbff`. Os componentes nativos de aplicação/restauração de arquivos permanecem dependentes da compatibilidade do iOS e do dispositivo; uma compilação aprovada não substitui teste no iPhone.

As licenças e avisos de terceiros do projeto original estão preservados dentro de `projeto-ios/`. Os READMEs originais nessa pasta descrevem o projeto de origem e podem mencionar recursos que não estão acessíveis nesta variante local; consulte este documento para a configuração entregue.
