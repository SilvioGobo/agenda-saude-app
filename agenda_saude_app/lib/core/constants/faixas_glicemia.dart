// Como uma medicao de glicemia capilar se compara com a faixa-alvo.
enum ClassificacaoGlicemia { muitoBaixa, baixa, naFaixa, alta, muitoAlta }

// Faixas de glicemia (mg/dL) usadas para classificar cada medicao registrada
// (RF008). Seguem o Consenso Internacional de Tempo no Alvo (Battelino et al.,
// Diabetes Care, 2019), adotado pela Sociedade Brasileira de Diabetes: alvo
// de 70 a 180 mg/dL; abaixo de 70 e hipoglicemia (abaixo de 54, muito baixa)
// e acima de 180 e alta (acima de 250, muito alta). O documento do TCC nao
// fixa os valores: se a equipe medica pedir metas individuais, e so mudar
// aqui.
class FaixasGlicemia {
  FaixasGlicemia._();

  static const int muitoBaixaAbaixoDe = 54;
  static const int alvoMinimo = 70;
  static const int alvoMaximo = 180;
  static const int muitoAltaAcimaDe = 250;

  // Valores aceitos na digitacao: a faixa que os glicosimetros medem (fora
  // dela o aparelho mostra "LO"/"HI" em vez de um numero).
  static const int minimoRegistravel = 20;
  static const int maximoRegistravel = 600;

  static ClassificacaoGlicemia classificar(double mgDl) {
    if (mgDl < muitoBaixaAbaixoDe) return ClassificacaoGlicemia.muitoBaixa;
    if (mgDl < alvoMinimo) return ClassificacaoGlicemia.baixa;
    if (mgDl <= alvoMaximo) return ClassificacaoGlicemia.naFaixa;
    if (mgDl <= muitoAltaAcimaDe) return ClassificacaoGlicemia.alta;
    return ClassificacaoGlicemia.muitoAlta;
  }

  static bool ehHipoglicemia(double mgDl) => mgDl < alvoMinimo;
}
