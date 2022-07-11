# 16red
redutor de videos acima de 16mb

dependência: ffmpeg ( https://ffmpeg.org/ )

projeto pessoal pra reduzir videos do whatsapp e formatar com codec correto para mandar para o whats com o limite de 16mb

reduz tamanho de video sem perda de qualidade notável usando libx264

efetivo em vídeos de 20-50 segundos


para implementar: 
  colocar vídeos em pastas temporárias (deletadas após reboot) em vez de substituir arquivo
  alerta quando o script acaba aumentando o tamanho em vez de reduzi-lo (deletar arquivo ou manter)
  escolha de qualidade, provavelmente colocar variável em crf
