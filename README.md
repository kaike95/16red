# 16red
redutor de videos acima de 16mb

dependência: ffmpeg ( https://ffmpeg.org/ )  **utilizar o package manager da sua distro 



projeto pessoal pra reduzir videos do whatsapp e formatar com codec correto para mandar para o whats com o limite de 16mb

reduz tamanho de video sem perda de qualidade notável usando libx264

efetivo em vídeos de 20-50 segundos


para implementar: 
  
	colocar vídeos em pastas temporárias (deletadas após reboot) em vez de substituir arquivo (parcialmente feito, cria uma nova pasta fora do local de execução do script)

  	alerta quando o script acaba aumentando o tamanho em vez de reduzi-lo (deletar arquivo ou manter)

  	escolha de qualidade, provavelmente colocar variável em crf


novo: 

cortar videos em seções de 15 segundos e formatar em 9:16

oculto banner do ffmpeg


