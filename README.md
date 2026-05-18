# CBIR — Group-of-Frame / Group-of-Picture Descriptor (MPEG-7)

Pràctica de Programació 2 — Sistemes de recuperació d'imatges per contingut (*Content-Based Image Retrieval*) basats en descriptors de color de l'estàndard MPEG-7, secció 13.5.

---

## Descripció del sistema

El sistema implementa un classificador d'imatges que, donada una imatge *query*, retorna les imatges més similars d'una base de dades. A diferència del Sistema 1 (histograma en escala de grisos), aquest sistema treballa en **color** i agrupa les imatges en **grups de 4** (GoP), representant cada grup amb un únic descriptor compacte basat en la **Scalable Color Descriptor (SCD)** via transformada de Haar.

```
Imatge Query (RGB)
      │
      ▼
 Histograma HSV (256 bins)
      │
      ▼
 Transformada de Haar (nivell 1) → 128 coeficients
      │
      ▼
 Distància MAE contra cada GoP indexat
      │
      ▼
 Llista ordenada d'imatges candidates
```

### Novetats respecte el Sistema 1 (histograma B/N)

| Aspecte | Sistema 1 | Sistema 2 (GoP) |
|---|---|---|
| Espai de color | Escala de grisos | HSV (color) |
| Unitat d'indexació | Imatge individual | Grup de 4 imatges (GoP) |
| Descriptor | Histograma 256 bins | SCD via Haar (128 coef.) |
| Agregació | — | Average / Median / Intersection |
| Distància | L1 / L2 | MAE (L1) |

---

## Estructura del repositori

```
CBIR/
├── 13_5gofigop.mlx       # Codi principal: GoP descriptor (Sistema 2)
├── classificador.mlx      # Codi del Sistema 1 (histograma B/N, referència)
├── classificador.pdf      # Export del Sistema 1
├── Histograma.m           # Funció auxiliar de càlcul d'histograma
├── RWTextFiles.m          # Funció auxiliar de lectura/escriptura de fitxers
├── input.txt              # Llista d'imatges query
├── output.txt             # Resultats del classificador
├── output05.txt           # Resultats amb llindar 0.5
├── prefeprofe.txt         # Fitxer de preferències
├── database/              # Base de dades d'imatges (UKBench, 2000 imatges)
└── README.md
```

---

## Descripció del codi (`13_5gofigop.mlx`)

### Bloc 1 — Configuració

Defineix els paths, el nombre d'imatges query (`Num_images = 20`), el nombre de candidats (`Candidates = 10`) i els paràmetres de la base de dades (`M = 2000` imatges, `Num_GoPs = 500` grups de 4).

### Bloc 2 — Construcció de la matriu de GoPs (indexació)

Per a cada GoP `g` (4 imatges consecutives de la base de dades):

1. Es llegeixen les 4 imatges i es converteixen a HSV
2. Es calcula l'histograma de 256 bins (16H × 4S × 4V) per a cadascuna
3. S'apliquen els **3 mètodes d'agregació** definits per l'estàndard MPEG-7:
   - **Average**: mitjana dels 4 histogrames normalitzats
   - **Median**: mediana bin a bin dels 4 histogrames normalitzats
   - **Intersection**: mínim bin a bin sobre *raw counts* (comptes sense normalitzar), capturant els trets de color comuns a totes les imatges del grup
4. S'aplica la **transformada de Haar** (nivell 1) a cada histograma agregat, guardant els 128 coeficients d'aproximació

> **Nota important sobre la intersecció**: es calcula sobre histogrames de comptes crus (no normalitzats) perquè l'estàndard la defineix com "el nombre de píxels d'un color determinat presents a totes les imatges del grup". Normalitzar prèviament desvirtua aquest significat i empitjora els resultats.

### Bloc 3 — Processament de les queries

Per a cada imatge del fitxer `input.txt`, es calcula el seu descriptor SCD de 128 coeficients de la mateixa manera que els GoPs (HSV → Haar nivell 1).

### Bloc 4 — Càlcul de distàncies i ranking

Per a cada mètode d'agregació i cada mètrica de distància:

1. Es calcula la distància MAE (L1) i Euclidiana (L2) de la query contra cada GoP
2. S'ordenen els GoPs de menor a major distància
3. S'expandeix el ranking de GoPs a imatges individuals (cada GoP conté les imatges `g×4` a `g×4+3`)

### Bloc 5 — Avaluació i gràfiques

- **Ground truth**: les 4 imatges del grup (inclosa la query) són totes rellevants (dataset UKBench)
- Es calculen precision i recall per a cada posició del ranking
- Es genera la corba Precision-Recall i el F-score màxim per a cada combinació de mètode × distància

---

## Resultats

### Gràfica Precision-Recall

> 📊 *Afegir aquí la captura de les gràfiques generades per `13_5gofigop.mlx`*

![Precision-Recall GoP]()

### Taula de resultats

| Descriptor | Distància | F-score | Temps/imatge (Lab) | Temps/imatge (PC) | Benchmark FFT |
|---|---|---|---|---|---|
| GoP-Average | MAE | — | — | — | — |
| GoP-Median | MAE | — | — | — | — |
| GoP-Intersection | MAE | — | — | — | — |

> *Omplir amb els valors obtinguts un cop executat el codi*

---

## Anàlisi dels resultats

### Comportament esperat vs. obtingut

**Intersection** és el mètode que hauria de donar millors resultats perquè captura els trets de color comuns a les 4 imatges del grup, que per definició del dataset UKBench són versions similars de la mateixa escena. És el descriptor més discriminatiu dels tres.

**Average** pot ser sensible a outliers (una imatge molt diferent de les altres 3 en llum o color pot desvirtuar la mitjana).

**Median** és robust a outliers però pot perdre matisos que sí captura la intersecció.

### Casos on els resultats no donen l'esperat

- **Intersecció amb histogrames normalitzats** (errada detectada i corregida): quan la intersecció es calcula sobre histogrames normalitzats en comptes de *raw counts*, els valors mínims bin a bin resulten massa petits i el descriptor perd poder discriminatiu. La intersecció passava a ser el pitjor mètode en lloc del millor.

- **Re-normalització de la mediana** (errada detectada i corregida): normalitzar el resultat de la mediana bin a bin no està especificat per l'estàndard i canvia el descriptor, afectant negativament els resultats.

- **Exclusió de la query del ranking** (errada detectada i corregida): excloure la pròpia imatge query de la llista de candidats i usar un denominador de recall = 3 és incorrecte per a UKBench, on les 4 imatges del grup (inclosa la query) són totes rellevants. El denominador correcte és 4.

### Proves alternatives realitzades

- **Comparació de nivells de Haar** (128 vs. 64 coeficients): es va implementar el pipeline per als dos nivells. Amb 128 coeficients s'obté millor resolució espectral i, en general, millors resultats.

- **256 coeficients (Haar complet)**: es va intentar concatenar els coeficients d'aproximació i detall per obtenir 256 valors, però la implementació va presentar problemes de compatibilitat de mides. Es va descartar en favor de 128 coeficients.

- **Distàncies L1 i L2**: es van comparar ambdues mètriques. L1 (MAE) és la recomanada per l'estàndard SCD i en general ofereix millors resultats per a histogrames.

### Possibles millores

- Provar amb més de 20 queries per obtenir resultats estadísticament més significatius
- Implementar la quantització no lineal dels coeficients Haar tal com especifica l'estàndard SCD
- Comparar el rendiment amb el Sistema 1 (histograma B/N) sobre el mateix conjunt de queries

### Principals dificultats

- Interpretar correctament la definició de la intersecció de l'estàndard (raw counts vs. normalitzat)
- Gestionar l'expansió de resultats a nivell de GoP → imatge individual mantenint la coherència del ranking
- Entendre quan la query ha d'apareixer o no en la llista de candidats i com afecta al recall

---

## Requisits

- MATLAB amb Wavelet Toolbox (funció `haart`)
- Base de dades UKBench (2000 imatges en format `ukbench00000.jpg` ... `ukbench01999.jpg`)
- Fitxer `input.txt` amb la llista d'imatges query

## Ús

1. Ajusta `User_root` i `Data_root` al Bloc 1 de `13_5gofigop.mlx` amb els teus paths locals
2. Executa el fitxer complet
3. Les gràfiques de Precision-Recall i la taula de F-scores es generaran automàticament

---

## Referència

> Ohm, J-R. et al. *Color Descriptors*, Chapter 13 in *Introduction to MPEG-7*, Wiley, 2002.
> Secció 13.5: Group-of-Frame or Group-of-Picture Descriptor.