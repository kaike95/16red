# 16red

redutor de videos acima de 16mb

Feito com ajuda de TomIO (https://github.com/TomJo2000)

dependência: ffmpeg ( https://ffmpeg.org/ )  **utilizar o package manager da sua distro 



Projeto pessoal pra reduzir videos do whatsapp e formatar com codec correto para mandar para o whats com o limite de 16mb

Reduz tamanho de video sem perda de qualidade notável usando libx264

Efetivo em vídeos de 20-50 segundos


Para implementar: 
  
	alerta quando o script acaba aumentando o tamanho em vez de reduzi-lo (deletar arquivo ou manter)

	escolha de qualidade, provavelmente colocar variável em crf

	adicionar modo não interativo denovo

novo: 

cria pasta com nome do arquivo e coloca vídeos completos dentro

vídeos em processos são enviados para pastas temporárias



velho:

Usabilidade melhorada:

Opções de parâmetros implementadas, removido a opção de executar o script fora do terminal (temporariamente)

Resolvido incompatibilidade de nomes

Adicionado a opção de ativar novamente o banner ffmpeg

Adicionado a opção de operar em apenas um arquivo

Suporte a mkv e mov adicionado
