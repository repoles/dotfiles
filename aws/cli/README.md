Não consegui configurar o `aws-cli` para procurar o arquivo de alias em `"$XDG_CONFIG_HOME"/aws/cli/alias`. A [documentação](https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-alias.html) informa apenas que o arquivo deve estar em `~/.aws/cli/alias`. Por conta disso, foi necessário criar um link simbólico:

```sh
mkdir -p ~/.aws/cli && ln -s "$XDG_CONFIG_HOME"/aws/cli/alias ~/.aws/cli/alias
```
