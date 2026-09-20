# LINKON OFFICE TOOL

Ferramenta de atendimento e manutenção do Microsoft Office para Windows, com identidade visual LinkOn.

## Identidade visual

A interface foi personalizada para seguir a logo LinkOn:

- **Fundo:** `#070012` — navy/preto profundo
- **Primária:** `#F80677` — magenta neon
- **Apoio:** `#4F0837` — vinho/magenta escuro
- **Texto:** `#F5F3F7` — branco suave

O terminal usa as cores nativas do Windows mais próximas desses tons para manter compatibilidade com PowerShell 5.1.

## Uso

1. Execute `LinkOn-OfficeTool.ps1` como administrador.
2. Use o atendimento automático ou uma função individual.
3. A ativação aceita apenas chave/licença válida.
4. Os logs são gravados em `C:\LinkOnOffice\Logs`.

## Estrutura

```text
LinkOn-OfficeTool/
├── LinkOn-OfficeTool.ps1
├── LEIA-ME.txt
├── README.md
└── assets/
    └── LinkOn-logo.jpg
```

## Aviso

O pacote usa a Office Deployment Tool e páginas oficiais da Microsoft para a instalação. Licenciamento e ativação dependem de uma licença válida e compatível com o produto instalado.


## Interface v3.0
A v3.0 usa uma interface gráfica Windows Forms com identidade visual LinkOn, menu por cards, painel de status do ambiente e console de operação. O atendimento automático continua disponível.
