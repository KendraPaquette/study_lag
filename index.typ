// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = [
  #line(start: (25%,0%), end: (75%,0%))
]

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): block.with(
    fill: luma(230), 
    width: 100%, 
    inset: 8pt, 
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.amount
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == "string" {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == "content" {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subrefnumbering: "1a",
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => numbering(subrefnumbering, n-super, quartosubfloatcounter.get().first() + 1))
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => {
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          }

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != "string" {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block, 
    block_with_new_content(
      old_title_block.body, 
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    new_title_block +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color, 
        width: 100%, 
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: white, width: 100%, inset: 8pt, body))
      }
    )
}

#let article(
  title: none,
  running-head: none,
  authors: none,
  affiliations: none,
  authornote: none,
  abstract: none,
  keywords: none,
  margin: (x: 2.5cm, y: 2.5cm),
  paper: "us-letter",
  font: ("Times New Roman"),
  fontsize: 12pt,
  leading: 2em,
  spacing: 2em,
  first-line-indent: 1.25cm,
  toc: false,
  cols: 1,
  doc,
) = {

  set page(
    paper: paper,
    margin: margin,
    header-ascent: 50%,
    header: grid(
      columns: (1fr, 1fr),
      align(left)[#running-head],
      align(right)[#counter(page).display()]
    )
  )
  
  set par(
    justify: false, 
    leading: leading,
    first-line-indent: first-line-indent
  )

  // Also "leading" space between paragraphs
  show par: set block(spacing: spacing)

  set text(
    font: font,
    size: fontsize
  )

  if title != none {
    align(center)[
      #v(8em)#block(below: leading*2)[
        #text(weight: "bold", size: fontsize)[#title]
      ]
    ]
  }
  
  if authors != none {
    align(center)[
      #block(above: leading, below: leading)[
        #let alast = authors.pop()
        #if authors.len() > 1 {
          // If multiple authors, join appropriately
          for a in authors [
            #a.name#super[#a.affiliations], 
          ] + [and #alast.name#super[#alast.affiliations]]
        } else {
          // If only one author, format a string
          [#alast.name#super[#alast.affiliations]]
        }
      ]
    ]
  }
  
  if affiliations != none {
    align(center)[
      #block(above: leading, below: leading)[
        #for a in affiliations [
          #super[#a.id]#a.name \
        ]
      ]
    ]
  }

  align(
    bottom,
    [
      #align(center, text(weight: "bold", "Author note"))
      #authornote
      // todo: The corresponding YAML field doesn't seem to work, so hacky
      Correspondence concerning this article should be addressed to
      #for a in authors [#if a.note == "true" [#a.name, #a.email]].
    ]
  )
  pagebreak()
  
  if abstract != none {
    block(above: 0em, below: 2em)[
      #align(center, text(weight: "bold", "Abstract"))
      #set par(first-line-indent: 0pt, leading: leading)
      #abstract
      #if keywords != none {[
        #text(weight: "regular", style: "italic")[Keywords:] #h(0.25em) #keywords
      ]}
    ]
  }
  pagebreak()

  /* Redefine headings up to level 5 */
  show heading.where(
    level: 1
  ): it => block(width: 100%, below: leading, above: leading)[
    #set align(center)
    #set text(size: fontsize)
    #it.body
  ]

  show heading.where(
    level: 2
  ): it => block(width: 100%, below: leading, above: leading)[
    #set align(left)
    #set text(size: fontsize)
    #it.body
  ]

  show heading.where(
    level: 3
  ): it => block(width: 100%, below: leading, above: leading)[
    #set align(left)
    #set text(size: fontsize, style: "italic")
    #it.body
  ]

  show heading.where(
    level: 4
  ): it => text(
    size: 1em,
    weight: "bold",
    it.body + [.]
  )

  show heading.where(
    level: 5
  ): it => text(
    size: 1em,
    weight: "bold",
    style: "italic",
    it.body + [.]
  )

  if cols == 1 {
    doc
  } else {
    columns(cols, gutter: 4%, doc)
  }
  
}
#show: doc => article(
  title: "Lagged Predictions of Next Week Alcohol Use for Precision Mental Health Support",
  authors: (
    (
      name: "Kendra Wyant",
      affiliations: "aff-1",
      email: [],
      note: ""
    ),
    (
      name: "Gaylen E. Fronk",
      affiliations: "aff-1",
      email: [],
      note: ""
    ),
    (
      name: "Jiachen Yu",
      affiliations: "aff-1",
      email: [],
      note: ""
    ),
    (
      name: "John J. Curtin",
      affiliations: "aff-1",
      email: [jjcurtin\@wisc.edu],
      note: ""
    ),
    
  ),
  affiliations: (
    (
      id: "aff-1",
      name: "Department of Psychology, University of Wisconsin-Madison"
    ),
    
  ),
  abstract: [We evaluated the performance of a model predicting immediate alcohol lapses and models with increasing lag time between the prediction time points and start of the prediction window (24, 72, 168, or 336 hour lag). Model features were engineered from 4x daily ecological momentary assessment. Participants (N =151; 51% male; mean age= 41; 87% White, 97% Non-Hispanic) were in early recovery from alcohol use disorder and provided data for up to three months. We used nested cross-validation to select and evaluate the best models. Median auROCs were high across models (range = 0.85 – 0.89). All lagged models performed significantly worse than the 0 lag model (probabilities \> .95). Comparisons between adjacent lags revealed significant differences between 24 and 72 hour lag models and 168 and 336 hour lag models. All models performed significantly worse for minority groups (not White vs.~non-Hispanic White, below poverty vs.~above poverty, female vs.~male).

],
  keywords: [Substance use disordersPrecision mental health],
  doc,
)


= Introduction
<introduction>
Precision medicine has been a goal in healthcare for over half a century @derubeisHistoryCurrentStatus2019. Traditionally, precision medicine seeks to answer the question of #emph[how] we best treat a specific individual, given their unique combination of genetic, lifestyle, and environmental characteristics (e.g., which medication is most effective for whom).

Today, this approach is also applied to chronic mental health conditions (i.e., precision mental health) such as depression, substance use disorders, and suicide. Mental health conditions are complex, fluctuating processes. Medical conditions often have clear biological precursors, which may be treated well with a single medication. In contrast, mental health conditions are products of numerous psychosocial factors, and treatments must be selected from a wide array of supports. Moreover, the factors driving mental health conditions differ between individuals and can change within an individual over time. Thus, precision mental health must consider both the #emph[how] and the #emph[when] (e.g., which treatment is most effective for whom at what moment).

There has been long-standing interest in precision mental health and substance use disorders. An early example is the Project MATCH research group, which attempted to match individuals with alcohol use disorder to their optimal treatment based on baseline measures of individual characteristics @projectmatchresearchgroupMatchingAlcoholismTreatments1997. Earlier studies, however, have been constrained to 1) low-dimensional analyses that fail to capture the complex and heterogeneous nature of substance use disorders and 2) the use of static distal features to predict a non-linear, time-varying course of recovery, lapse, and relapse @witkiewitzModelingComplexityPosttreatment2007.

Recent advances in both machine learning and personal sensing may address these barriers to successful precision mental health. Machine learning uses high dimensional inputs that can capture the complexity of mental health conditions. Moreover, tools from machine learning can be applied to models to understand which factors are important to a specific individual at a specific moment in time, addressing the question of #emph[how];.

Personal sensing allows for frequent, longitudinal measurement of changes in proximal risk (e.g., for a lapse) with high temporal precision, for better understanding the #emph[when];. This precision is particularly important for predicting discrete symptoms or behaviors. Take the example of lapses, discrete instances of goal inconsistent substance use. Lapses are a clinically important target for substance use treatment. They are often an early warning sign of relapse, and maladaptive responses to lapses can undermine recovery. For some substances, even a single lapse can result in an overdose and/or death. It would be unreasonable to expect that we could predict a lapse with any temporal precision using only features that become more distal as time progresses. Rather, lapse prediction requires dense, long-term monitoring of symptoms and related states proximal to the outcome.

Ecological momentary assessment (EMA) may be particularly well-suited for risk prediction algorithms. It offers momentary subjective insight into constructs that can be easily mapped onto modular forms of treatment, such as the relapse prevention model @marlattRelapsePreventionMaintenance1985@witkiewitzRelapsePreventionAlcohol2004. EMA also appears to be well tolerated by individuals with substance use disorders @wyantAcceptabilityPersonalSensing2023. Thus, it can serve as an important signal for predicting substance use outcomes and interpreting clinically relevant features over a sustained period.

Promising preliminary work suggests it is possible to build EMA models that predict immediate lapses back to substance use @waltersUsingMachineLearning2021@baeMobilePhoneSensors2018@soysterPooledPersonspecificMachine2022@chihPredictiveModelingAddiction2014. In a previous study from our group, we demonstrated that we can do this very well @wyantMachineLearningModels2023. We used 4X daily EMA with questions designed to measure theoretically-implicated risk factors including past use, craving, past pleasant events, past and future risky situations, past and future stressful events, emotional valence and arousal, and self-efficacy. We showed that it was possible to predict immediate alcohol lapses for several different prediction widths with clinically meaningful accuracy.

Narrow prediction window widths (i.e., next hour or next day) without any lag time between the prediction time point and start of the prediction window are well-suited for #emph[Just-in-Time] interventions that make algorithm-guided recommendations to address immediate risks - for example, recommending a coping with craving activity when someone has increased craving, or recommending a guided relaxation video when someone is reporting recent stressful events. Importantly, these supports can be available 24/7 (e.g., in a digital therapeutic) for an individual, allowing them to take action right away.

However, many interventions cannot be self-contained in a digital therapeutic and take time to set up. For example, someone who has reported recent past alcohol use and low abstinence self-efficacy might be encouraged to attend a self-help meeting, plan an outing with important people in their life, or schedule an appointment with a therapist. These multimodal interventions (i.e., combined human and digital interventions) are not available 24/7. A #emph[time-lagged] model where prediction windows are shifted further into the future (i.e., away from the prediction time point) could provide patients with increased lead time to implement supports that might not be immediately available to them. In these situations, a wider prediction window width (i.e, one week) may be preferred. Wider window widths yield higher proportions of positive labels mitigating issues of an unbalanced outcome. Additionally, when scheduling real world support, it is important that the lead up time is adequate and not that the prediction is necessarily temporally precise.

In this study, we evaluated the performance of a model predicting immediate next week lapses compared to models using increased lag time between the prediction time points and the start of the prediction window. Specifically, we used the same EMA features as our immediate model and trained new models to predict the probability of a lapse beginning one day (24 hours), three days (72 hours), one week (168 hours), or two weeks (336 hours) into the future. We evaluated each lagged model to determine if they perform at clinically implementable levels and assessed the relative difference in performance as lag time increased.

Additionally, our group is committed to the responsible and transparent reporting of model performance. Models that work for only a subset of people, if implemented, could widen existing treatment disparities. Therefore we reported our models’ performance for three dichotomized demographic groups with known disparities in access to substance use treatment - race and ethnicity (not White vs.~non-Hispanic White) @pinedoCurrentReexaminationRacial2019@kilaruIncidenceTreatmentOpioid2020, income (below poverty vs.~above poverty) @olfsonHealthcareCoverageService2022, and sex at birth (female vs.~male) @greenfieldSubstanceAbuseTreatment2007@kilaruIncidenceTreatmentOpioid2020.

= Methods
<methods>
== Transparency and Openness
<transparency-and-openness>
We adhere to research transparency principles that are crucial for robust and replicable science. We preregistered our data analytic strategy. We reported how we determined the sample size, all data exclusions, all manipulations, and all study measures. We provide a transparency report in the supplement. Finally, our data, analysis scripts, annotated results, questionnaires, and other study materials are publicly available (#link("https://osf.io/xta67/");).

== Participants
<participants>
We recruited participants in early recovery (1-8 weeks of abstinence) from moderate to severe alcohol use disorder in Madison, Wisconsin, US for a three month longitudinal study. One hundred fifty one participants were included in our analyses. We used data from all participants included in our previous study (see @wyantMachineLearningModels2023 for enrollment and disposition information). This sample size was determined based on traditional power analysis methods for logistic regression @hsiehSampleSizeTables1989 because comparable approaches for machine learning models have not yet been validated. Participants were recruited through print and targeted digital advertisements and partnerships with treatment centers. We required that participants:

+ were age 18 or older,
+ could write and read in English,
+ had at least moderate AUD (\>= 4 self-reported DSM-5 symptoms),
+ were abstinent from alcohol for 1-8 weeks, and
+ were willing to use a single smartphone (personal or study provided) while on study.

We also excluded participants exhibiting severe symptoms of psychosis or paranoia.

== Procedure
<procedure>
Participants completed five study visits over approximately three months. After an initial phone screen, participants attended an in-person screening visit to determine eligibility, complete informed consent, and collect self-report measures. Eligible, consented participants returned approximately one week later for an intake visit. Three additional follow-up visits occurred about every 30 days that participants remained on study. Participants were expected to complete four daily EMAs while on study. Other personal sensing data streams (geolocation, cellular communications, sleep quality, and audio check-ins) were collected as part of the parent grant’s aims (R01 AA024391). Participants could earn up to \$150/month if they completed all study visits, had 10% or less missing EMA data and opted in to provide data for other personal sensing data streams.

== Measures
<measures>
=== Ecological Momentary Assessments
<ecological-momentary-assessments>
Participants completed four brief (7-10 questions) EMAs daily. The first and last EMAs of the day were scheduled within one hour of participants’ typical wake and sleep times. The other two EMAs were scheduled randomly within the first and second halves of their typical day, with at least one hour between EMAs. Participants learned how to complete the EMA and the meaning of each question during their intake visit.

On all EMAs, participants reported dates/times of any unreported past alcohol use. Next, participants rated the maximum intensity of recent (i.e., since last EMA) experiences of craving, risky situations, stressful events, and pleasant events. Finally, participants rated their current affect on two bipolar scales: valence (Unpleasant/Unhappy to Pleasant/Happy) and arousal (Calm/Sleepy to Aroused/Alert).

On the first EMA each day, participants also rated the likelihood of encountering risky situations and stressful events in the next week and the likelihood that they would drink alcohol in the next week (i.e., abstinence self-efficacy).

=== Individual Characteristics
<individual-characteristics>
We collected self-report information about demographics (age, sex, race, ethnicity, education, marital status, employment, and income) and AUD symptom count to characterize our sample. Demographic information was also included as features in our models and a subset (sex, race, ethnicity, and income) used for model fairness analyses.

As part of the aims of the parent project we collected many other trait and state measures throughout the study. A complete list of all measures can be found on our study’s OSF page.

== Data Analytic Strategy
<data-analytic-strategy>
Data preprocessing, modeling, and Bayesian analyses were done in R using the tidymodels ecosystem @kuhnTidymodelsCollectionPackages2020@kuhnTidyposteriorBayesianAnalysis2022@goodrichRstanarmBayesianApplied2023. Models were trained and evaluated using high-throughput computing resources provided by the University of Wisconsin Center for High Throughput Computing @chtc.

=== Predictions
<predictions>
@fig-methods shows how we established prediction time points, windows, and lags. All available data up until, but not including, the prediction time point was used to generate model predictions. Prediction time points were updated hourly (Panel A). The first prediction time point for each participant was 24 hours from midnight on their study start date. This ensured at least 24 hours of past EMAs for future lapse prediction at these first time points. Subsequent predictions time points for each participant repeatedly rolled hour-by-hour until the end of their study participation.

The prediction window width was one week. Prediction windows rolled forward hour-by-hour with the prediction time point (Panel B). There were five possible lag times between the prediction time point and start of the prediction window. A prediction window either started immediately after the prediction time point (0 lag) or was lagged by 24, 72, 168, or 336 hours.

Therefore, our models provided hour-by-hour probabilities of an alcohol lapse in the next week pushed out up to two weeks into the future.

#block[
#figure([
#box(image("index_files/figure-typst/notebooks-mak_figures-fig-methods-output-1.png"))
], caption: figure.caption(
position: bottom, 
[
We used all available data up until the prediction timepoint to generate features using varying scoring epochs. Prediction timepoints rolled forward hour-by-hour (Panel A). Prediction windows were 1 week wide. A prediction window started immediately after the prediction timepoint (0 lag) or was lagged by 24, 72, 168, or 336 hours (Panel B).
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-methods>


]
=== Labels
<labels>
The start and end date/time of past drinking episodes were reported on the first EMA item. A prediction window was labeled #emph[lapse] if the start date/hour of any drinking episode fell within that window. A window was labeled #emph[no lapse] if no alcohol use occurred within that window +/- 24 hours. If no alcohol use occurred within the window but did occur within 24 hours of the start or end of the window, the window was excluded.

We ended up with a total of 270,081 labels for our baseline (no lag) model, 266,599 labels for our 24 hour lagged model, 259,643 labels for our 72 hour lagged model, 245,707 labels for our 168 hour lagged model, and 221,206 labels for our 336 hour lagged model.

=== Feature Engineering
<feature-engineering>
Features were calculated using only data collected before the start of each prediction window to ensure our models were making true future predictions. For our no lag models this included all data prior to the hour of the start of the prediction window. For our lagged models, the last EMA data used for feature engineering were collected up to 24 hours, 72 hours, 168 hours, or 336 hours prior to the start of the prediction window.

A total of 279 features were derived from two data sources:

+ #emph[Demographics];: We created quantitative features for age and personal income, and dummy-coded features for sex, race/ethnicity, marital status, education, and employment.

+ #emph[Previous EMA responses];: We created raw EMA and change features for varying scoring epochs (i.e., 12, 24, 48, 72, and 168 hours) before the start of the prediction window for all EMA items. Raw features included min, max, and median scores for each EMA item across all EMAs in each epoch for that participant. We calculated change features by subtracting the participants’ overall mean score for each EMA item (using all EMAs collected before the start of the prediction window) from the associated raw feature. We also created raw and change features based on the most recent response for each EMA question and raw and change rate features from previously reported lapses and number of completed EMAs.

Other generic feature engineering steps included imputing missing data (median imputation for numeric features, mode imputation for nominal features) and removing zero and near-zero variance features as determined from held-in data (see Cross-validation section below).

=== Model Training and Evaluation
<model-training-and-evaluation>
==== Model Configurations
<model-configurations>
We trained and evaluated five separate classification models: one baseline (no lag) model and one model for 24 hour, 72 hour, 168 hour, and 336 hour lagged predictions. We considered four well-established statistical algorithms (elastic net, XGBoost, regularized discriminant analysis, and single layer neural networks) that vary across characteristics expected to affect model performance (e.g., flexibility, complexity, handling higher-order interactions natively) @kuhnAppliedPredictiveModeling2018.

Candidate model configurations differed across sensible values for key hyperparameters. They also differed on outcome resampling method (i.e., no resampling and up-sampling and down-sampling of the outcome using majority/no lapse to minority/lapse ratios ranging from 1:1 to 2:1). We calibrated predicted probabilities using the beta distribution to support optimal decision-making under variable outcome distributions @kullSigmoidsHowObtain2017.

==== Cross-validation
<cross-validation>
We used participant-grouped, nested cross-validation for model training, selection, and evaluation with auROC. auROC indexes the probability that the model will predict a higher score for a randomly selected positive case (lapse) relative to a randomly selected negative case (no lapse). Grouped cross-validation assigns all data from a participant as either held-in or held-out to avoid bias introduced when predicting a participant’s data from their own data. We used 1 repeat of 10-fold cross-validation for the inner loops (i.e., #emph[validation] sets) and 3 repeats of 10-fold cross-validation for the outer loop (i.e., #emph[test] sets). Best model configurations were selected using median auROC across the 10 validation sets. Final performance evaluation of those best model configurations used median auROC across the 30 test sets.

==== Bayesian Model
<bayesian-model>
We used a Bayesian hierarchical generalized linear model to estimate the posterior probability distributions and 95% Bayesian credible intervals (CIs) from the 30 held-out test sets for our five best models. Following recommendations from the rstanarm team and others @rstudioteamRStudioIntegratedDevelopment2020@gabryPriorDistributionsRstanarm2023, we used the rstanarm default autoscaled, weakly informative, data-dependent priors that take into account the order of magnitude of the variables to provide some regularization to stabilize computation and avoid over-fitting.#footnote[Priors were set as follows: residual standard deviation \~ normal(location=0, scale=exp(2)), intercept (after centering predictors) \~ normal(location=2.3, scale=1.3), the two coefficients for window width contrasts \~ normal (location=0, scale=2.69), and covariance \~ decov(regularization=1, concentration=1, shape=1, scale=1).] We set two random intercepts to account for our resampling method: one for the repeat, and another for the fold nested within repeat. We specified two sets of contrasts for model comparisons. The first set compared each lagged model to the baseline model (0 lag vs.~24 hour lag, 0 lag vs.~72 hour lag, 0 lag vs.~168 lag, 0 lag vs.~336 lag). The second set compared adjacently lagged models (24 hour lag vs.~72 hour lag, 72 hour lag vs.~168 hour lag, 168 hour lag vs.~336 hour lag). auROCs were transformed using the logit function and regressed as a function of model contrast.

From the Bayesian model we obtained the posterior distribution (transformed back from logit) and Bayeisan CIs for all five models. To evaluate our models’ overall performance we report the median posterior probability for auROC and Bayesian CIs. This represents our best estimate for the magnitude of the auROC parameter for each model. If the confidence intervals do not contain .5 (chance performance), this suggests our model is capturing signal in the data.

We then conducted Bayesian model comparisons using our two sets of contrasts - baseline and adjacent lags. For both model comparisons, we determined the probability that the models’ performances differed systematically from each other. We also report the precise posterior probability for the difference in auROCs and the 95% Bayesian CIs. If there was a probability \>.95 that the more lagged model’s performance was worse, we labeled the model contrast as significant.

==== Fairness Analyses
<fairness-analyses>
We calculated the median posterior probability and 95% Bayesian CI for auROC for each model separately by race and ethnicity (not White vs.~non-Hispanic White), income (below poverty vs.~above poverty#footnote[The poverty cutoff was defined from the 2024 federal poverty line for the 48 continguous United States. Participants at or below \$1560 annual income were categorized as below poverty.@mba2024FederalPoverty2024];), and sex at birth (female vs.~male). We conducted Bayesian group comparisons to assess the likelihood that each model performs differently by group. We report the median difference and range in posterior probabilities across all models. The median auROC and Bayesian CIs are reported separately by group and model in the supplement.#footnote[For our fairness analyses, we altered our outer loop resampling method from 3 x 10 cross-validation to 6 x 5 cross-validation. This method still gave us 30 held out tests sets, but by splitting the data across fewer folds (i.e., 5 vs.~10) we were able to reduce the likelihood of the minority group being absent in any single fold.]

==== Feature Importance
<feature-importance>
We calculated Shapley values in log-odds units for binary classification models from the 30 test sets to provide a description of the importance of categories of features across our five models @lundbergUnifiedApproachInterpreting2017. We averaged the three Shapley values for each observation for each feature (i.e., across the three repeats) to increase their stability. An inherent property of Shapley values is their additivity, allowing us to combine features into feature categories. We created separate feature categories for each of the nine EMA questions, the rates of past alcohol use and missing surveys, the time of day and day of the week of the start of the prediction window, and the seven demographic variables included in the models. We calculated the local (i.e., for each observation) importance for each category of features by adding Shapley values across all features in a category, separately for each observation. We calculated global importance for each feature category by averaging the absolute value of the Shapley values of all features in the category across all observations. These local and global importance scores based on Shapley values allow us to contextualize relative feature importance for each model.

= Results
<results>
== Demographic and Lapse Characteristics
<demographic-and-lapse-characteristics>
There were approximately equal numbers of men (N=77; 51.0%) and women (N=74; 49.0%) who ranged in age from 21 - 72 years old. The sample was majority White (N=131; 86.8%) and non-Hispanic (N=147; 97.4%). Participants self-reported a median of 9.0 DSM-5 symptoms of AUD and most participants (N=84; 55.6%) reported one or more lapses during participation. @tbl-demohtml provides more detail on demographic and lapse characteristics of the sample.

#block[
#block[
#figure([
#block[
#figure(
  align(center)[#table(
    columns: (45.74%, 6.38%, 7.45%, 11.7%, 11.7%, 14.89%),
    align: (left,right,right,left,left,left,),
    table.header([var], [N], [%], [M], [SD], [Range],),
    table.hline(),
    [Age], [], [], [41], [11.9], [21-72],
    [Sex], [], [], [], [], [],
    [Female], [74], [49.0], [], [], [],
    [Male], [77], [51.0], [], [], [],
    [Race], [], [], [], [], [],
    [American Indian/Alaska Native], [3], [2.0], [], [], [],
    [Asian], [2], [1.3], [], [], [],
    [Black/African American], [8], [5.3], [], [], [],
    [White/Caucasian], [131], [86.8], [], [], [],
    [Other/Multiracial], [7], [4.6], [], [], [],
    [Hispanic, Latino, or Spanish origin], [], [], [], [], [],
    [Yes], [4], [2.6], [], [], [],
    [No], [147], [97.4], [], [], [],
    [Education], [], [], [], [], [],
    [Less than high school or GED degree], [1], [0.7], [], [], [],
    [High school or GED], [14], [9.3], [], [], [],
    [Some college], [41], [27.2], [], [], [],
    [2-Year degree], [14], [9.3], [], [], [],
    [College degree], [58], [38.4], [], [], [],
    [Advanced degree], [23], [15.2], [], [], [],
    [Employment], [], [], [], [], [],
    [Employed full-time], [72], [47.7], [], [], [],
    [Employed part-time], [26], [17.2], [], [], [],
    [Full-time student], [7], [4.6], [], [], [],
    [Homemaker], [1], [0.7], [], [], [],
    [Disabled], [7], [4.6], [], [], [],
    [Retired], [8], [5.3], [], [], [],
    [Unemployed], [18], [11.9], [], [], [],
    [Temporarily laid off, sick leave, or maternity leave], [3], [2.0], [], [], [],
    [Other, not otherwise specified], [9], [6.0], [], [], [],
    [Personal Income], [], [], [\$34,298], [\$31,807], [\$0-200,000],
    [Marital Status], [], [], [], [], [],
    [Never married], [67], [44.4], [], [], [],
    [Married], [32], [21.2], [], [], [],
    [Divorced], [45], [29.8], [], [], [],
    [Separated], [5], [3.3], [], [], [],
    [Widowed], [2], [1.3], [], [], [],
    [DSM-5 AUD Symptom Count], [], [], [8.9], [1.9], [4-11],
    [Reported 1 or More Lapse During Study Period], [], [], [], [], [],
    [Yes], [84], [55.6], [], [], [],
    [No], [67], [44.4], [], [], [],
    [Number of reported lapses], [], [], [6.8], [12], [0-75],
  )]
  , kind: table
  )

]
], caption: figure.caption(
position: top, 
[
Demographic and Lapse Characteristics
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-demohtml>


]
]
== Model Evaluation
<model-evaluation>
The median auROC across the 30 test sets for our baseline model was high (median=0.893, IQR=0.045), consistent with our previous study.#footnote[Baseline models in our previous study yielded a median auROC of .895. These models inadvertently excluded income and employment as features. We reran models to include these features in the current study.] Performance across our lagged models was also high for the 24 hour lag (median=0.882, IQR=0.039), 72 hour lag (median=0.868, IQR=0.057), 168 hour lag (median=0.860, IQR=0.062), and 336 hour lag (median=0.856, IQR=0.062).

Histograms of the full posterior probability distributions for auROC for each model are available in the supplement. The median auROCs from these posterior distributions were 0.893 (baseline), 0.887 (24 hour lag), 0.875 (72 hour lag), 0.871 (168 hour lag), and 0.852 (336 hour lag). These values represent our best estimates for the magnitude of the auROC parameter for each model. The 95% Bayesian CI for the auROCs for these models were relatively narrow and did not contain 0.5: baseline \[0.876-0.908\], 24 hour lag \[0.869-0.903\], 72 hour lag \[0.855-0.892\], 168 hour lag \[0.850-0.889\], 336 hour lag \[0.830-0.872\]. Panel A in @fig-1 displays these median auROCs and 95% Bayesian CIs by model.

#block[
#figure([
#box(image("index_files/figure-typst/notebooks-mak_figures-fig-1-output-1.png"))
], caption: figure.caption(
position: bottom, 
[
Panel A depicts posterior probability for area under ROC curve (auROC) and Bayesian credible intervals by model. Dashed line indicates a model performing at chance. Panel B depicts difference in auROCs by demographic group
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-1>


]
== Model Comparisons
<model-comparisons>
=== Baseline Contrasts
<baseline-contrasts>
The median decrease in auROC for the baseline vs.~24 hour lag model was 0.006 (95% CI=\[0.000-0.012\]), yielding a significant probability of 0.960 that the lagged model had worse performance. The median decrease in auROC for the baseline vs.~72 hour model was 0.018 (95% CI=\[0.012-0.025\]), yielding a significant probability of 1.000 that the lagged model had worse performance. The median decrease in auROC for the baseline vs.~168 hour lag model was 0.023 (95% CI=\[0.016-0.029\]), yielding a significant probability of 1.000 that the lagged model had worse performance. The median decrease in auROC for the baseline vs.~336 hour lag model was 0.041 (95% CI=\[0.033-0.049\]), yielding a significant probability of 1.000 that the lagged model had worse performance.

=== Adjacent Contrasts
<adjacent-contrasts>
The median decrease in auROC for the 24 hour vs.~72 hour lag model was 0.012 (95% CI=\[0.006-0.019\]), yielding a significant probability of 1.000 that the 72 hour lag model had worse performance than the 24 hour lag model. The median decrease in auROC for the 72 hour vs.~168 hour lag model was 0.004 (95% CI=\[-0.002-0.011\]), yielding a non-significant probability of 0.865 that the 168 hour lag model had worse performance than the 72 hour lag model. The median decrease in auROC for the 168 hour vs.~336 hour lag model was 0.018 (95% CI=\[0.011-0.025\]), yielding a significant probability of 1.000 that the 336 hour lag model had worse performance than the 168 hour lag model.

== Fairness Analyses
<fairness-analyses-1>
Panel B in @fig-1 shows the difference in performance of each model by race (not White; #emph[N] = 20 vs.~Non-Hispanic White; #emph[N] = 131), sex at birth (female; #emph[N] = 74 vs.~Male; #emph[N] = 77), and income (below poverty; #emph[N] = 18 vs.~above poverty; #emph[N] = 133). All group comparisons were significant (probability \> .95) across models. On average there was a median decrease in auROC of 0.159 (range 0.107-0.179) for participants who were not White compared to non-Hispanic White participants. On average there was a median decrease in auROC of 0.080 (range 0.059-0.116) for female participants compared to male participants. On average there was a median decrease in auROC of 0.092 (range 0.086-0.133) for participants below the federal poverty line compared to participants above the federal poverty line. Table 1 in the supplement shows the median auROC and credible intervals separately by group and model.

== Feature Importance
<feature-importance-1>
Global importance (mean |Shapley value|) for feature categories for each model appears in Panel A of @fig-shap. The top three feature categories for all models were past use, future efficacy, and craving. Future risky situations were also globally important across models. This category was ranked as the 4th most important feature across lagged models (24, 72, 168, and 336 hours). For the immediate model (0 hour lag), past risky situations were ranked as the 4th most important feature category and future risky situations was ranked as the fifth most important. Income was the only demographic feature that emerged as having high global importance for lapse prediction (in top 6 for all models). A table of feature categories ranked by global importance for each model is available in the supplement.

Panel B shows the local feature importance scores colored by high or low feature value for the baseline (0 lag) model. Local feature importance plots for our other models can be found in the supplement. Future abstinence efficacy, future risky situations, and income appear to have a linear relationship to lapse prediction. Higher efficacy, fewer future risky situations, and higher income were associated with a lower likelihood that the model would predict a lapse. In the supplement, we plot the relationship between Shapley value and feature score individually for our overall top five features by model.

#block[
#figure([
#box(image("index_files/figure-typst/notebooks-mak_figures-fig-shap-output-1.png"))
], caption: figure.caption(
position: bottom, 
[
Panel A depicts the global importance (mean |Shapley value|) for feature categories for each model. Feature categories are ordered by their aggregate global importance (i.e., total bar length) across the five models. The importance of each feature category for specific models is displayed separately by color. Panel B shows the local feature importance for the 0 hour lagged model.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-shap>


]
== Discussion
<discussion>
== Model Performance
<model-performance>
Our models performed exceptionally well with median posterior probabilities for auROCs of .85 - .89. This suggests we can achieve clinically meaningful performance up to two weeks out. Our rigorous resampling methods (grouped, nested, k-fold cross-validation) make us confident that these are valid estimates of how our models would perform with new individuals.

Nevertheless, model performance did significantly decrease as models predicted further into the future. This is unsurprising given what we know about prediction and substance use. First, as lag time increases, features become less proximal to the prediction time point. Many important relapse risk factors are fluctuating processes that can change day-by-day, if not more frequently. For example, cravings can come on quickly (e.g., after encountering a person or place that reminds them of their use) and typically only last for up to 30 minutes. It may be acceptable to miss some of these more dynamic risk factors, however, if we consider lagged models as a supplement to immediate lapse prediction models (i.e., models with no lag). Lagged prediction models are most useful for their ability to provide individuals with advance notice that they may be at risk for lapsing. This advance notice can be used to implement more time-intensive recovery supports, such as attending a support group. On the other hand, an immediate lapse prediction model (i.e., no lag) is well-suited for detecting immediate risk and making a recommendation just-in-time (e.g., pointing to an activity available 24/7 on the web).

We saw mixed evidence that feature importance might change depending on lag. Past use and craving were the top two features for all models. This suggests that although these features can change quickly, they are important enough to consistently emerge as top predictors regardless of lag time. Recent past risky situations, however, ranked high for the immediate prediction models, but future anticipated risky situations was relatively more important for the lagged models.

Second, participants only provided EMA for up to three months. Therefore, a lag time of two weeks between the prediction time point and start of the prediction window prohibits us from using 1/6th of the EMA data for predictions. It is possible that this loss of data contributed to decreased performance in the lagged models. In a separate NIH protocol underway, participants are providing EMA and other sensed data for up to 12 months @moshontzProspectivePredictionLapses2021. By comparing models built from these two datasets, we will better be able to evaluate whether this loss of data impacted model performance and if we can sustain similar performance with even longer lags in these data. Still, we wish to emphasize that our lowest auROC (.85) is still excellent, and the benefit of advanced notice likely outweighs the cost to performance.

== Model Fairness
<model-fairness>
All models performed worse for women, for people who were not White, and for people who had an income below the poverty line. The largest contributing factor is likely the lack of diversity in our training data. For example, even with our coarse combination of race/ethnicity, the not White group was largely underrepresented relative to the non-Hispanic White group. The best solution to this limitation would be to recruit a more representative sample. However, there may be methods to mitigate these issues in the current data. We could explore upsampling minority group representation in the data (e.g., using synthetic minority oversampling technique). We also could adjust the penalty weights so that prediction errors for minority groups are weighted more heavily than prediction errors for majority groups.

Lastly, we could consider building models for a specific individual (i.e., idiographic) @fisherOpenTrialPersonalized2019@wrightAppliedAmbulatoryAssessment2019. Person-specific models consider the characteristics and behaviors important to an individual rather than generalizing across a population. Unfortunately, a person-specific lapse prediction model requires a sufficient number of positive labels (i.e., lapses) for that individual. Waiting until an individual has lapsed multiple (perhaps many) times to offer help is in direct opposition with our goals. One potential solution to this conundrum may involve departing from traditional machine learning algorithms. For example, state space models, which are grounded in traditional repeated measures designs, inherently capture time series data and allow for the modeling of how an individual’s risk evolves over time from observable and latent states.

Although representation in our data is likely a contributing factor, it is not the only factor affecting model fairness. We had equal representation of men and women, and we still saw differences in performance. This difference is likely due to another source of bias - measurement bias. We chose our EMA items based on domain expertise and years of relapse risk research. It is possible that these constructs more precisely describe relapse risk factors for men than for women. This could mean that more research is needed to identify relapse risk factors for women (and other groups underrepresented in the literature more broadly). Additionally, data driven (bottom-up) approaches to creating features could be one way to remove some of the bias in domain driven (top-down) approaches. For example, using natural language processing on text message content could allow for new categories of features to emerge.

== Additional Limitations and Future Directions
<additional-limitations-and-future-directions>
All of the proposed suggestions above for improving model fairness are current directions in our lab. In our current sample of participants, we are building models that prioritize accuracy for underrepresented groups. We are also building models that use other sensing methods, like geolocation and text message content, separately and in conjunction with EMA. In these combined models, we plan to assess whether the relative top features differs by demographic group. For example, it is possible that data-driven features (e.g., from geolocation) emerge as more important for groups that have been historically underrepresented in the research on relapse risk factors driving our self-report measures. To increase the diversity of our data, we recruited a nationally representative sample of people with opioid use disorder (data collection is near complete) @moshontzProspectivePredictionLapses2021.

Measurement burden of EMA is also a concern. Research suggests people can comply with effortful sensing methods (e.g., 4x daily EMA) while using substances @wyantAcceptabilityPersonalSensing2023@jonesComplianceEcologicalMomentary2019a. However, it is likely that frequent daily surveys will eventually become too burdensome when considering long-term monitoring. We plan to build models that use only 1x daily EMA to evaluate the trade-off between model performance and assessment burden. We also plan to build models that combine EMA and passive sensing methods, like geolocation, and evaluate the important features. It is possible that adding other low burden sensing methods could allow us to reduce the frequency (e.g., 1x weekly EMA) and/or length (e.g, 2-3 items) of our EMAs.

Finally, to address disparities in substance use treatment initiation and outcomes among underrepresented groups, it is important to solicit and consider individual preferences and perceptions of the sensing data used to build an algorithm-guided risk monitoring support system from the beginning (i.e., #emph[before] an intervention is developed). Providing a support tool only acceptable to a majority group could widen existing disparities. To this end, we are currently using a mixed-methods design to assess issues related to feasibility and acceptability by sensing method and demographic characteristics in our national sample of participants with opioid use disorder.

== Conclusion
<conclusion>
This study suggests it is possible to predict alcohol lapses up to two weeks into the future. This advanced notice could allow patients to implement multimodal support options not immediately available. Important steps are still needed to make these models clinically implementable. Most notably, is the increased fairness in model performance. However, we remain optimistic as we have already begun to take several steps in addressing these barriers.

== References
<references>
#block[
] <refs>



#set bibliography(style: "apa")

#bibliography("references.bib")

