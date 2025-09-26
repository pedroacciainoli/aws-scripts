# Scripts AWS - Automação EC2

Este repositório contém scripts em Bash para automatizar a criação e configuração de instâncias EC2 na AWS, incluindo:

- Criação de VPC, Subnet, Internet Gateway e Route Table
- Configuração de Security Group com regras para SSH (porta 22) e HTTP (porta 80)
- Geração de Key Pair (.pem) e configuração de permissões
- Instalação automática do servidor web Apache via user data
- Obtenção dinâmica da última AMI Amazon Linux 2
- Exposição do endereço público da instância para acesso à web

---

## Como usar

1. Clone o repositório:

git clone https://github.com/SEU_USUARIO/SEU_REPOSITORIO.git
cd SEU_REPOSITORIO



2. Torne o script executável e execute:

chmod +x ec2-script.sh
./ec2-script.sh


3. Insira suas credenciais AWS conforme solicitado.

4. Após execução, o script retornará o IP público para acessar sua instância EC2.

---

## Observações

- Necessita AWS CLI instalado e configurado para rodar.
- Script criado para rodar em Linux e macOS.
- Caso utilize credenciais temporárias (token de sessão), garanta que o session token seja configurado corretamente.

---

## Contribuição

Sinta-se à vontade para melhorar e abrir pull requests!

---

## Contato

Luis Pedro - pedro.acciainoli@gmail.com
