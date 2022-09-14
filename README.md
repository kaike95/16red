# 16red

redutor de videos acima de 16mb

Feito com ajuda de TomIO (https://github.com/TomJo2000)

dependência: ffmpeg ( https://ffmpeg.org/ )  **utilizar o package manager da sua distro 



Projeto pessoal pra reduzir videos do whatsapp e formatar com codec correto para mandar para o whats com o limite de 16mb

Reduz tamanho de video sem perda de qualidade notável usando libx264

Efetivo em vídeos de 20-50 segundos


Para implementar: 
  
	perguntar se quer colocar vídeos antigos em pastas temporárias (deletadas após reboot) em vez de substituir arquivo (parcialmente feito, cria uma nova pasta no local de execução do script)

  	alerta quando o script acaba aumentando o tamanho em vez de reduzi-lo (deletar arquivo ou manter)

  	escolha de qualidade, provavelmente colocar variável em crf

	adicionar modo não interativo denovo

novo: 


Usabilidade melhorada:

Opções de parâmetros implementadas, removido a opção de executar o script fora do terminal (temporariamente)

Resolvido incompatibilidade de nomes

Adicionado a opção de ativar novamente o banner ffmpeg

Adicionado a opção de operar em apenas um arquivo

Suporte a mkv e mov adicionado
