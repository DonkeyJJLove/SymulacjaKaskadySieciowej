## Modelowanie wektorów ataku – jak to robić **badawczo**, a nie operacyjnie

Poniżej znajduje się zwięzły opis w jaki sposób można zaprojektować model *wektorów ataku kaskadowego* (ang. *attack-cascade model*) tak, aby służył do analizy ryzyka i odporności systemu, **a nie do planowania realnych operacji**.

---

#### 1. Cel analityczny, a nie bojowy

Modele kaskad ataku powstają po to, by zrozumieć **strukturalne słabości** złożonych systemów (państwa, sieci energetycznych, łańcuchów dostaw). Interesuje nas:

* jak mały, ukierunkowany impuls (presja ekonomiczna, cenzura, propaganda) może propagować się w systemie,
* które węzły i sprzężenia decydują o skalowaniu szkód,
* jakie parametry (np. kohezja elit, morale, kontrola informacji) mają największą czułość w sensie Morrisa/Sobola.

Model **nie** powinien produkować listy celów ani procedur ataku, a jedynie wskazać, które *klasy zjawisk* (np. blackout informacyjny) mają największy wpływ na trajektorię systemu.

---

#### 2. Formalizacja wektorów ataku

W wektorach nie kodujemy „instrukcji uderzenia”, lecz **parametry scenariusza**:

| Wektor                   | Interpretacja w modelu                             | Przykład parametru            |
| ------------------------ | -------------------------------------------------- | ----------------------------- |
| **Presja militarna**     | Intensywność konfliktu zewnętrznego `X(t)`         | Amplituda szoku, czas trwania |
| **Sankcje ekonomiczne**  | `San(t)` – siła ograniczeń handlu                  | Poziom 0-1, profil w czasie   |
| **Zakłócenia łączności** | `C(t)` – spadek kontroli informacji wskutek blokad | Procent sieci wyłączonej      |
| **Szlak energetyczny**   | `H(t)` – zakłócenia cieśniny / rurociągu           | Odsetek utraconego eksportu   |

Każdy wektor to **sygnał wejściowy** o zadanym kształcie, a nie recepta „jak to zrobić”.

---

#### 3. Sprzężenia zwrotne zamiast celów punktowych

Model SD ujmuje mechanizmy typu:

```
Sankcje → spadek fiskusa → obniżenie lojalności → wzrost represji → krzywda → protesty
```

Takie ujęcie pozwala testować hipotezy („czy blackout + inflacja < 30 % rocznie wystarczy do pęknięcia elit?”) **bez** wskazywania, jak blackout technicznie przeprowadzić.

---

#### 4. Analiza wrażliwości jako narzędzie etycznego „czerwonego zespołu”

Metody Morrisa (µ★) i Sobola (S₁/ST):

* identyfikują parametry, które *najbardziej zmieniają wynik* (czas do załamania, prawdopodobieństwo pęknięcia elit),
* pokazują, czy wpływ jest addytywny czy wynika z interakcji.

Wynik „k_info ≈ 0.32 ST” oznacza, że **skuteczność kontroli informacji** jest krytycznym punktem obrony; nie mówi jednak, *jak* ją złamać.

---

#### 5. Raportowanie a nie instrukcje

Końcowy output to:

* **metryki ryzyka** (np. 80 % symulacji przełamuje stabilność < 12 tyg),
* **mapy czułości** (które parametry trzeba monitorować / wzmacniać),
* **scenariusze „co-jeśli”** (czy podwyższenie rezerw walutowych opóźni kaskadę?).

Brak w nim łańcucha operacyjnego czy sugestii działań kinetycznych – model służy **prewencji i odporności**, nie agresji.

---

#### 6. Praktyka użycia oprogramowania

1. **Definiujesz scenariusz** w pliku YAML – amplitudy `X(t)`, `San(t)` itp.
2. **Uruchamiasz** skrypty `run_morris.py`, `run_sobol.py`, aby zobaczyć, które wektory są najgroźniejsze *w teorii*.
3. **Analizujesz** wyniki: jeśli np. `k_mob` i `k_info` dominują, wiesz, że *społeczna mobilizacja* i *informacja* to główne dźwignie – zarówno dla obrony, jak i dla stabilizacji po kryzysie.
4. **Wnioskujesz** o politykach odporności (redundantna infrastruktura, bufory fiskalne), zamiast projektować ataki.

---
