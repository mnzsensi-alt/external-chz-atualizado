# Migração para Objective-C/UIKit

## Estado

A migração integral do aplicativo ainda não foi concluída. Esta é a primeira etapa de uma conversão incremental.

## Portado nesta etapa

- `PreviewDashboardViewController.h/.m` implementa em UIKit/Objective-C as telas de prévia Function e AIMBOT.
- A antiga implementação das telas em `LiveDashboardView.swift` foi removida do target e do repositório.
- `ContentView.swift` mantém um adaptador SwiftUI (`UIViewControllerRepresentable`) para apresentar os controllers Objective-C durante a migração.
- O bridging header e o projeto Xcode incluem a nova interface Objective-C.

Os interruptores da tela são apenas elementos de prévia visual; não ativam nem implementam recursos de jogo.

## Ainda não portado

O ponto de entrada do app, o shell de navegação SwiftUI, as demais telas, modelos, stores, serviços e helpers permanecem majoritariamente em Swift. A migração completa desses componentes exigirá etapas adicionais de UIKit/Objective-C e interoperabilidade temporária.

## Módulos mantidos em Swift

Os módulos de exploração de baixo nível permanecem em Swift e não fazem parte desta migração Objective-C.

## Validação

`git diff --check` passou. O build de IPA foi tentado pelo GitHub Actions duas vezes; ambas as execuções foram canceladas sem alocar um runner macOS e sem iniciar etapas do Xcode. Portanto, esta etapa ainda não tem confirmação de compilação no Xcode.

## Próximas etapas sugeridas

1. Substituir o shell de navegação `ContentView` por `UITabBarController` em Objective-C, preservando temporariamente os controllers Swift das abas não portadas.
2. Portar as telas funcionais restantes por domínio (repositórios, navegador de dados/arquivos, patches, cleaner e wallpaper), acompanhadas pelos seus modelos e serviços não relacionados à exploração.
3. Remover adaptadores e fontes Swift que deixarem de ser necessários, mantendo somente os componentes que não serão portados.
4. Executar build e testes em um runner macOS antes de marcar a conversão concluída.
