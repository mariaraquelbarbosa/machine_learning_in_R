# Instalação de bibliotecas
install.packages("WDI")
install.packages("formattable")

# Chamando as libraries
library(formattable)
library(WDI) # baixar os dados do World Bank
library(magrittr)

################# Preparação dos Dados #################

# Procura por uma palavra-chave na base de dados do Banco Mundial
WDIsearch("Inflation")

# Listamos os indicadores econômicos escolhidos
lista_indicadores <- c("FP.CPI.TOTL.ZG", # inflação (%)
                       "NY.GDP.PCAP.CD", # Pib per capita (USD)
                       "NY.GDP.MKTP.KD.ZG", # crescimento do PIB anual (%),
                       "SL.UEM.TOTL.ZS" # Desemprego (%)
)

# Usando 2014
df2014 <- WDI(indicator = lista_indicadores, country = "all", start = 2014, end = 2014,
              extra = TRUE)
str(df2014)

# Removendo agregados geográficos
df2014$region %<>% as.character
df2014 <- subset(df2014, region != "Aggregates")

# Dataframe com as variáveis que nos interessam
dfi2014 <- df2014[, lista_indicadores]
row.names(dfi2014) <- df2014$country
colnames(dfi2014) <- c("Inflacao", "PIB_per_Capita", "Crescimento_PIB", "Desemprego")

# Coloca "NA" quando não há valores + transforma taxa de desemprego em taxa de emprego
dfi2014 <- na.omit(dfi2014)
dfi2014$Desemprego <- 100 - dfi2014$Desemprego
names(dfi2014)[4] <- "Emprego"
View(dfi2014)


################# Análise de Agrupamento #################


# Transforma os valores -> 0 = média; < 0 = abaixo da média; > 0 = acima da média
dfi2014_escala <- scale(dfi2014)

# Soma dos quadrados com diferentes quantidades de grupos
wss <- (nrow(dfi2014_escala)-1)*sum(apply(dfi2014_escala,2,var))
for (i in 2:15) wss[i] <- sum(kmeans(dfi2014_escala,
                                     centers=i)$withinss)
plot(1:15, wss, type="b", xlab="Número de Grupos",
     ylab="Soma dos quadrados dentro dos grupos")

# Criação de dendograma
dendo <- dfi2014_escala %>% dist %>% hclust
plot(dendo)
rect.hclust(dendo, k = 4, border = "blue")
rect.hclust(dendo, k = 5, border = "red")
rect.hclust(dendo, k = 8, border = "green")

################# Análise dos Resultados #################

# Visualizando os clusters
library(cluster)
library(fpc)
grupos <- kmeans(dfi2014_escala, centers=5)
clusplot(dfi2014_escala, grupos$cluster, color=TRUE, shade=TRUE, labels=2, lines=0)

# Distância entre Brasil e alguns outros países
dfi2014_escala[c("Brazil", "Chile", "Colombia", "Norway", "United States"),] %>% dist

# 5 países mais similares ao Brasil
mat_brasil[, "Brazil"] %>% sort() %>% head(6)

# 5 países mais similares ao Brasil
mat_brasil[, "Brazil"] %>% sort() %>% tail(5)

# Criação dos segmentos
  # fixar uma seed (semente) para garantir a reprodutibilidade da análise:
set.seed(123)
  # criar os clusters ou grupos
lista_clusteres <- kmeans(dfi2014_escala, centers = 5)$cluster
  # função customizada para calcular a média dos indicadores para cada cluster
cluster.summary <- function(data, groups) {
  x <- round(aggregate(data, list(groups), mean), 2)
  x$qtd <- as.numeric(table(groups))
  # colocar coluna de quantidade na segunda posição
  x <- x[, c(1, 6, 2, 3, 4, 5)]
  return(x)
}
(tabela <- cluster.summary(dfi2014, lista_clusteres))

# Formatação da segmentação
colorir.valor <- function(x) ifelse(x >= mean(x), style(color = "green"), style(color =
                                                                                  "red"))
nome_colunas <- c("Cluster", "Quantidade de países do Grupo", "Taxa de Inflação (%)",
"PIB Per Capita (US$)","Crescimento anual do PIB (%)", "Taxa de Emprego(%)")

formattable(
  tabela,
  list(
    pib_per_capita = formatter("span", style = x ~ colorir.valor(x)),
    crescimento_pib = formatter("span", style = x ~ colorir.valor(x)),
    emprego = formatter("span", style = x ~ colorir.valor(x))
  ), col.names = nome_colunas, format = "markdown", pad = 0
)

# Determinar em que cluster o Brasil está
dfi2014$cluster <- lista_clusteres
dfi2014["Brazil",]

cl_brasil <- dfi2014["Brazil", ]$cluster
x <- dfi2014[dfi2014$cluster == cl_brasil, ]
x[order(-x$PIB_per_Capita),] %>% knitr::kable()