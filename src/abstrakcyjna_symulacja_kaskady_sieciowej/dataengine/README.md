# **Pełen standard normalizacji danych** dla tego modelu 

Od surowych źródeł do finalnych zmiennych wejściowych `0–1`, z rozróżnieniem na zmienne obserwowalne, mieszane i latentne. Standard jest zrobiony tak, żeby był obronny metodologicznie dla Iranu, ale dał się też wdrożyć technicznie pod SD z krokiem tygodniowym. ACLED dostarcza zdarzenia protestów i przemocy kodowane na poziomie eventów, World Bank ma publiczne API wskaźników makro, UN Comtrade udostępnia dane handlowe w częstotliwości rocznej i miesięcznej, a OPEC publikuje comiesięczny MOMR dla rynku ropy. ([ACLED][1])

## 1. Zasada nadrzędna

Każda zmienna modelu musi przejść przez ten sam pipeline:

```text
Źródło surowe
→ walidacja metodologiczna
→ harmonizacja czasu
→ harmonizacja jednostek
→ korekta braków i outlierów
→ transformacja rozkładu
→ normalizacja do wspólnej skali
→ agregacja do wskaźnika modelowego
→ zapis wersji raw + transformed + normalized
```

**Nigdy nie trzymasz tylko wersji znormalizowanej.**
Dla każdej serii muszą istnieć równolegle:

* `raw`
* `clean`
* `transformed`
* `normalized`
* `final_model_input`

To jest kluczowe, bo inaczej nie odróżnisz efektu rzeczywistego od artefaktu obróbki.

---

## 2. Klasy zmiennych i ich reżim normalizacji

### Klasa A — zmienne bezpośrednio obserwowalne

Przykłady:

* liczba protestów,
* liczba blackout days,
* CPI,
* produkcja ropy,
* eksport/import,
* liczba nowych sankcji.

Dla nich stosujesz:

* harmonizację częstotliwości,
* ewentualną transformację log,
* normalizację statystyczną lub percentylową.

### Klasa B — zmienne obserwowalne pośrednio

Przykłady:

* represyjność,
* presja zewnętrzna,
* stres gospodarczy,
* zdolność fiskalna.

Dla nich stosujesz:

* budowę indeksu z 2–4 obserwabli,
* standaryzację składników,
* ważoną agregację.

### Klasa C — zmienne latentne

Przykłady:

* morale społeczne,
* lojalność aparatu,
* spójność elit.

Dla nich nie wolno udawać, że są „mierzone”.
Muszą być oznaczone jako:

* `latent_proxy_index`
* z jawną listą składowych,
* z jawnymi wagami,
* z testem stabilności wag.

---

## 3. Harmonizacja czasu

Twój model działa tygodniowo, więc wszystkie serie muszą być sprowadzone do osi tygodniowej.

### A. Dane dzienne

Przykłady: blackouty, eventy ACLED.

Reguła:

* agregacja do tygodnia `t`
* dla event counts: suma tygodniowa
* dla intensywności: średnia tygodniowa lub suma ważona

Przykład:

```text
protest_count_week_t = Σ protest_events_day_d
```

### B. Dane miesięczne

Przykłady: handel, ropa, CPI.

Reguła:

* nie duplikuj surowo tej samej wartości na 4 tygodnie bez oznaczenia
* twórz wersje:

  * `step-hold`
  * `linear-interpolated`
* do SD domyślnie używaj `step-hold`, chyba że zmienna jest ciągła i gładka

Zalecenie:

* `CPI`, `trade`, `oil production`: `step-hold`
* `inflation pressure index`: można interpolować liniowo

### C. Dane kwartalne/roczne

Przykłady: część makro, SIPRI, Freedom House.

Reguła:

* traktować jako **warstwę tła strukturalnego**
* nie używać ich jako jedynego nośnika zmiany tygodniowej
* dekomponować na:

  * komponent strukturalny wolnozmienny
  * komponent zdarzeniowy z innych źródeł

To szczególnie ważne przy Freedom House: to bardzo dobra miara strukturalnej restrykcyjności, ale nie nadaje się sama do tygodniowego wykrywania nagłych zmian. ([Data Help Desk][2])

---

## 4. Harmonizacja jednostek

Wszystkie serie muszą zostać sprowadzone do jednej z pięciu postaci:

1. **count per week**
2. **rate per population**
3. **index relative to baseline**
4. **real value / constant price**
5. **probability-like score 0–1**

### A. Zdarzenia

Dla protestów, represji, blackoutów:

* licz jako `count`
* dodatkowo licz per capita, najlepiej:

```text
rate_per_million = count / population * 1,000,000
```

### B. Ceny i handel

Dla CPI, eksportu, produkcji:

* trzymaj poziom,
* trzymaj zmianę r/r,
* trzymaj odchylenie od trendu 12-mies.

### C. Sankcje

Sankcje to nie „count zwykły”.
Muszą mieć wagę sektorową:

* personalne: 1
* instytucjonalne: 2
* finansowe: 3
* energetyczne / shipping / banking systemic: 4

Wtedy:

```text
sanctions_intensity_t = Σ weighted_new_sanctions_t
```

---

## 5. Obsługa braków danych

To jest krytyczny element.

### Reżim braków

#### A. Brak losowy krótki

Do 1–2 obserwacji:

* liniowa interpolacja dla zmiennych ciągłych
* forward fill tylko dla wskaźników stock-like

#### B. Brak blokowy

Powyżej 3 kolejnych okresów:

* nie imputować bezwarunkowo
* oznaczyć flagę jakości:

```text
quality_flag = low
```

* w modelu używać tylko po agregacji z innymi źródłami

#### C. Brak strukturalny

Np. zmienna latentna nie ma bezpośredniego źródła:

* nie imputować z powietrza
* budować indeks z dostępnych proxy

### Zasada

Każda imputacja musi tworzyć kolumnę:

* `is_imputed`
* `imputation_method`

Bez tego seria nie jest naukowo audytowalna.

---

## 6. Obsługa outlierów

W Iranie outliery bywają realne, więc nie wolno ich automatycznie ucinać.

### A. Event data

Protest spike, blackout spike, repression spike:

* zachowuj
* nie winsoryzuj automatycznie
* jedynie dodaj wersję wygładzoną obok wersji raw

### B. Makro i handel

Dla handlu, eksportu, cen:

* sprawdzaj anomalię względem rolling median i MAD
* jeśli anomalia wynika z błędu raportowania, oznacz i koryguj
* jeśli wynika z realnego szoku, zachowaj

### Reguła detekcji technicznej

```text
robust_z = (x_t - median_window) / MAD_window
```

Jeśli `|robust_z| > 5`, seria idzie do ręcznego przeglądu.

---

## 7. Transformacja rozkładu

Nie wszystkie serie nadają się do bezpośredniego skalowania.

### A. Event counts i koszty

Dla protest counts, violence counts, blackout cost:

```text
x' = log(1 + x)
```

### B. Udziały i proporcje

Jeżeli seria już jest w `[0,1]`, nie rób min-max bez potrzeby.
Możesz zostawić albo użyć logit tylko do modelowania, nie do dashboardu.

### C. Serie silnie skośne

Dla handlu, eksportu, migracji:

* `log(1+x)` albo `Box-Cox`, ale tylko jeśli dodatnie
* dla praktyki projektowej: `log(1+x)` wystarcza

---

## 8. Właściwa normalizacja

To jest rdzeń standardu.

## 8.1. Normalizacja dla zdarzeń tygodniowych

Przykłady:

* protesty,
* violence against civilians,
* blackout days.

### Krok 1

Per capita:

```text
x_pc_t = x_t / population_t * 1,000,000
```

### Krok 2

Wygładzenie:

```text
x_sm_t = mean(x_pc_{t-3:t})
```

albo EWMA:

```text
x_sm_t = α x_t + (1-α) x_sm_{t-1}
```

z `α = 0.3`

### Krok 3

Skalowanie odporne:

```text
x_norm_t = clip((x_sm_t - P10) / (P90 - P10), 0, 1)
```

### Dlaczego percentyle, nie zwykły min-max

Bo min-max jest niestabilny przy pojedynczych ekstremach.
Percentyl `P10–P90` daje większą odporność na epizody skrajne.

---

## 8.2. Normalizacja dla cen, handlu i ropy

Przykłady:

* CPI,
* produkcja ropy,
* eksport,
* import.

### Wersja bazowa

Najpierw licz zmianę względem historii:

```text
delta_12m_t = (x_t / mean(x_{t-12:t-1})) - 1
```

albo:

```text
z_robust_t = (x_t - median_36m) / MAD_36m
```

### Wersja modelowa

Następnie:

```text
x_norm_t = sigmoid(z_robust_t / k)
```

gdzie zwykle `k = 2`

To daje płynny wskaźnik `0–1` bez brutalnego obcinania.

### Znak kierunku

Musisz jawnie ustalić orientację:

* inflacja: wyżej = gorzej
* CPI growth: wyżej = gorzej
* produkcja ropy: wyżej = lepiej dla reżimu
* eksport: wyżej = lepiej dla reżimu

Więc dla serii „pozytywnych” odwracasz tam, gdzie budujesz indeks stresu:

```text
stress_component = 1 - normalized_resource_capacity
```

---

## 8.3. Normalizacja dla sankcji

Sankcje są zmienną zdarzeniową z ciężarem jakościowym.

### Krok 1

Zakoduj typ:

```text
personal = 1
institutional = 2
financial = 3
energy_shipping_banking = 4
```

### Krok 2

Agregacja miesięczna:

```text
san_raw_t = Σ weight_i
```

### Krok 3

Wygładzenie:

```text
san_sm_t = mean(san_raw_{t-2:t})
```

### Krok 4

Skalowanie:

```text
san_norm_t = clip(san_sm_t / P95, 0, 1)
```

Nie używałbym tu z-score, bo rozkład jest bardzo zerowy i impulsowy.

---

## 8.4. Normalizacja dla blackoutów i kontroli informacji

To wymaga rozdzielenia na dwie warstwy.

### A. Warstwa strukturalna

Freedom House:

* traktowana jako wolnozmienny poziom bazowy restrykcyjności cyfrowej. ([Data Help Desk][2])

Normalizacja:

```text
fh_norm = (score - min_score) / (max_score - min_score)
```

albo po prostu przeskalowanie do `0–1`.

### B. Warstwa zdarzeniowa

NetBlocks / Cloudflare / OONI:

* blackout days
* depth of disruption
* cost

Normalizacja:

```text
blackout_days_norm_t = disrupted_days_t / days_in_period
cost_norm_t = log(1+cost_t) / log(1+P95_cost)
```

### C. Finalna zmienna `InfoControlShock`

```text
info_shock_t = 0.6 * blackout_days_norm_t + 0.4 * cost_norm_t
```

### D. Finalna zmienna `Info`

Jeśli `Info` ma oznaczać **kontrolę informacji przez reżim**, a nie tylko zakłócenie, to:

```text
Info_t = 0.7 * structural_restriction + 0.3 * info_shock_t
```

Jeśli ma oznaczać **sprawność otwartego przepływu informacji**, to odwracasz znak.

---

## 8.5. Normalizacja dla migracji i kosztu humanitarnego

UNHCR daje dobre serie dla uchodźców i wybranych przepływów humanitarnych. ([UN Comtrade][3])

### Krok 1

Per capita:

```text
disp_pc_t = displaced_t / population_t * 100,000
```

### Krok 2

Transformacja:

```text
disp_log_t = log(1 + disp_pc_t)
```

### Krok 3

Normalizacja:

```text
disp_norm_t = clip((disp_log_t - P10) / (P90 - P10), 0, 1)
```

---

## 9. Budowa zmiennych latentnych

Tu jest najważniejsza część naukowa.

## 9.1. `Morale`

Nie obserwujesz morale wprost. Budujesz je jako odwrotność stresu społecznego.

### Składniki

* protest intensity
* inflation stress
* blackout intensity
* migration stress

### Wzór

```text
social_stress_t =
    0.35 * protest_norm_t +
    0.30 * infl_norm_t +
    0.20 * blackout_norm_t +
    0.15 * displaced_norm_t

Morale_t = 1 - social_stress_t
```

### Reguła

Wagi nie mogą być arbitralne na zawsze.
Trzeba przeprowadzić:

* analizę wrażliwości wag,
* test stabilności rankingu.

---

## 9.2. `Fiscal`

### Składniki

* oil revenue index
* trade stability
* inflation inverse

### Wzór

```text
Fiscal_t =
    0.50 * oilrev_norm_t +
    0.30 * trade_capacity_norm_t +
    0.20 * (1 - infl_norm_t)
```

### Uwaga

Jeżeli masz dane krajowe o revenue lub budget balance dobrej jakości, zastępujesz nimi część proxy. World Bank ma szeroką bazę wskaźników i publiczne API, więc może być główną warstwą makro. ([Data Help Desk][2])

---

## 9.3. `Elite` i `Loyal`

To najtrudniejsze zmienne.

### `Elite`

Proponowany indeks:

* dymisje/czystki publiczne,
* personal sanctions on insiders,
* public elite conflict events,
* spadek spójności reakcji państwa.

```text
EliteStress_t =
    0.4 * elite_conflict_events_norm +
    0.3 * personal_sanctions_norm +
    0.3 * governance_disruption_norm

Elite_t = 1 - EliteStress_t
```

### `Loyal`

Proponowany indeks:

* brak defekcji,
* skuteczność utrzymania kontroli przy wysokim proteście,
* brak widocznych pęknięć w aparacie bezpieczeństwa.

```text
LoyalStress_t =
    0.5 * security_defection_norm +
    0.3 * repression_failure_norm +
    0.2 * elite_split_norm

Loyal_t = 1 - LoyalStress_t
```

To nadal będzie proxy niskiej lub średniej jakości, i tak należy to opisywać.

---

## 10. Finalny standard skalowania do modelu

Po zbudowaniu każdej zmiennej końcowej musisz doprowadzić ją do wspólnej konwencji:

### Konwencja

* `0` = skrajnie słabo / brak zdolności / niski poziom
* `1` = skrajnie wysoko / pełna zdolność / wysoki poziom

Ale tylko przy zmiennych stock-like.

Dla zmiennych typu stres:

* albo trzymasz je jako stres `0–1`, gdzie wyżej = gorzej,
* albo od razu odwracasz przy wejściu do modelu.

### Reguła repozytoryjna

Nie mieszaj obu konwencji w jednej tabeli bez jawnego pola:

```text
semantic_direction = positive_state | stress_state
```

---

## 11. Minimalny zestaw wzorów implementacyjnych

## 11.1. Event counts

```text
x1 = count_per_week / population * 1e6
x2 = EWMA(x1, alpha=0.3)
x3 = clip((x2 - P10) / (P90 - P10), 0, 1)
```

## 11.2. Makro / handel / ropa

```text
x1 = log(1 + raw_value)
x2 = (x1 - median_36m) / MAD_36m
x3 = 1 / (1 + exp(-x2 / 2))
```

## 11.3. Sankcje

```text
x1 = weighted_sum_new_sanctions
x2 = rolling_mean_3m(x1)
x3 = clip(x2 / P95, 0, 1)
```

## 11.4. Latent index

```text
index = Σ w_i * component_i_norm
```

z warunkiem:

```text
Σ w_i = 1
```

---

## 12. Standard jakości i audytu

Każda seria wejściowa powinna mieć metadane:

| pole                | opis                                     |
| ------------------- | ---------------------------------------- |
| `source_primary`    | główne źródło                            |
| `source_secondary`  | źródło walidacyjne                       |
| `frequency_raw`     | częstotliwość surowa                     |
| `frequency_model`   | częstotliwość po harmonizacji            |
| `unit_raw`          | jednostka surowa                         |
| `transform`         | np. `log1p`, `none`, `robust_z`          |
| `normalization`     | np. `p10_p90_minmax`, `sigmoid_robust_z` |
| `orientation`       | `higher_is_worse` / `higher_is_better`   |
| `imputation_method` | jeśli użyto                              |
| `quality_proxy`     | high / medium / low                      |
| `latent_flag`       | true / false                             |

Bez tego nie masz pełnego standardu naukowego, tylko obróbkę roboczą.

---

## 13. Rekomendowany standard końcowy dla tego projektu

Dla Twojego zadania rekomenduję dokładnie ten zestaw:

### Zdarzenia polityczne

* ACLED
* tygodniowo
* per mln
* EWMA
* `P10–P90 min-max`

### Kontrola informacji

* Freedom House jako poziom strukturalny
* NetBlocks/Cloudflare/OONI jako warstwa szokowa
* osobna normalizacja
* składanie ważone

### Makro

* World Bank jako warstwa bazowa
* miesięcznie
* `log1p` jeśli potrzeba
* `robust z-score`
* `sigmoid`

### Handel

* UN Comtrade
* miesięcznie
* odchylenie od 12-mies. trendu
* `robust z-score`

### Ropa

* OPEC
* miesięcznie
* indeks relatywny do 12-mies. średniej
* `0–1` po sigmoid/percentylach

### Sankcje

* OFAC
* scoring sektorowy
* 3-mies. smoothing
* skala do `P95`

### Humanitarian

* UNHCR
* per capita
* `log1p`
* percentylowe skalowanie

---

## 14. Wniosek metodologiczny

**Pełen standard normalizacji** dla tego modelu nie powinien być jednym uniwersalnym min-maxem.
Powinien być **warstwowy**:

* event data → per capita + smoothing + percentylowe skalowanie
* macro/trade/oil → trend-relative + robust z-score + sigmoid
* sanctions → weighted event index
* latent constructs → transparent weighted composite
* wszystkie serie → wersja raw + transformed + normalized + metadata


