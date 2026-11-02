// Em que ponto esta a leitura de um relatorio: buscando os registros, pronto
// para mostrar ou com falha (sem internet, sem permissao...). Em caso de erro a
// tela nao mostra numeros - um relatorio incompleto passaria a impressao de
// que o paciente nao fez nada - e oferece "Tentar novamente".
enum EstadoRelatorio { carregando, pronto, erro }
