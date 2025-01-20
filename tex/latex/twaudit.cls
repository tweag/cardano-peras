\newcommand\fileversion{0.0.1}
\newcommand\filedate{2021/10/06}
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{twaudit}[\filedate\space Tweag Audit Template (v\fileversion)]

% Base Class
\def\TWA@Base{report}

% Font Size
\DeclareOption{10pt}{\PassOptionsToClass{10pt}{\TWA@Base}}%
\DeclareOption{11pt}{\PassOptionsToClass{11pt}{\TWA@Base}}%
\DeclareOption{12pt}{\PassOptionsToClass{12pt}{\TWA@Base}}%

% Page Size
\newcommand\TWA@papersize{a4paper} % Set Default as a4paper
\DeclareOption{a4paper}{\renewcommand\TWA@papersize{a4paper}}
\DeclareOption{a5paper}{\renewcommand\TWA@papersize{a5paper}}
\DeclareOption{b5paper}{\renewcommand\TWA@papersize{b5paper}}
\DeclareOption{letterpaper}{\renewcommand\TWA@papersize{letterpaper}}
\PassOptionsToClass{\TWA@papersize}{\TWA@Base}%

\newif\ifTWA@isdraft
\TWA@isdraftfalse
\DeclareOption{draft}{
\TWA@isdrafttrue
\PassOptionsToClass{draft}{\TWA@Base}
}

% If someone ever wants to print an audit, cmyk will guarantee
% the printed colors are faithful
\DeclareOption{cmyk}{\PassOptionsToPackage{cmyk}{xcolor}}

%% Here we can pass undeclared options to some class
%% or package
\DeclareOption*{%
  \ClassWarning{twaudit}{Unknown option '\CurrentOption'.
I'll pass it to '\TWA@Base' just in case.}
  \PassOptionsToClass{\CurrentOption}{\TWA@Base}%
}
\ProcessOptions\relax
%% This finishes the 'options' section

%% We'll build on top of the '\TWA@Base' class.
\LoadClass{\TWA@Base}

%% Necessary Packags
\RequirePackage{xcolor}
\RequirePackage{tikz}
\RequirePackage{ccaption}
\RequirePackage{graphicx}
\RequirePackage{setspace}
\RequirePackage{amsmath}
\RequirePackage{amssymb}

%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%
%% Font Selection %%
%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%

%% Font selection is an art. Font selection in LaTeX is black magic.
%% Not only there is subjective artistic
%% component of which font combination "looks better", but there is also
%% a technical component of which fonts actually work together and, finally,
%% one has to take licenses into account.
%%
%% After much fighting, I managed to bring Tweag's core font, Stratos, into
%% headings; I made the executive decision to stick to libertineRoman for the
%% body text for a few reasons:
%%
%%   i) Its a typographical faux-pas to use sans-serif everywhere, especially for dense text.
%%      They really read better as the serif helps guide the eyes.
%%  ii) libertineRoman has good \textsc shape
%% iii) a serif fond for the body does not clash with math, and sans-serif math fonts look
%%      horrible.
%%
%%
%% Finally, I'm using DejaVu Sans Mono for \ttfamily; its a reasonable coding font,
%% has good \textbf and \textit and is freely available.
%%
%% With all that being said; in order to get all of that to work, the following commands
%% MUST BE ISSUED IN THAT SPECIFIC ORDER:
\usepackage{fontspec}
\newfontfamily\stratosL{Stratos Light}
\newfontfamily\stratosR{Stratos Regular}
\newfontfamily\stratosM{Stratos Medium}
\newfontfamily\stratosB{Stratos Bold}

\usepackage[T1]{fontenc}
\usepackage{libertineRoman}
\setmonofont[Scale=MatchLowercase]{DejaVu Sans Mono}

%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%
%% Our Commands %%
%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%

\newcommand{\HRule}{\rule{\linewidth}{0.5mm}} % Defines a new command for horizontal lines, change thickness here
\newcommand{\dnormalspacing}{1.2}
\newcommand{\dcompressedspacing}{1.0}

% Block quote with compressed spacing
\let\oldquote\quote
\let\endoldquote\endquote
\renewenvironment{quote}
    {\begin{spacing}{\dcompressedspacing}\oldquote}
    {\endoldquote\end{spacing}}

% Itemize with compressed spacing
\let\olditemize\itemize
\let\endolditemize\enditemize
\renewenvironment{itemize}
    {\begin{spacing}{\dcompressedspacing}\olditemize}
    {\endolditemize\end{spacing}}

% Enumerate with compressed spacing
\let\oldenumerate\enumerate
\let\endoldenumerate\endenumerate
\renewenvironment{enumerate}
    {\begin{spacing}{\dcompressedspacing}\oldenumerate}
    {\endoldenumerate\end{spacing}}

%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%
%% Text Layout %%
%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%

\RequirePackage{geometry}
%% Margins and Geometry config
\geometry{\TWA@papersize}
\geometry{centering}

%% Customize table and figure captions
\RequirePackage{caption}
\captionsetup[table]{labelfont={sc},textfont={sl},justification=RaggedRight}
\captionsetup[figure]{labelfont={sc},textfont={sl},justification=RaggedRight}

% Front matter.
\setcounter{tocdepth}{2} %% Show subsections in the TOC
\usepackage[titles]{tocloft}
\usepackage[titletoc]{appendix}
\renewcommand{\cftsecleader}{\cftdotfill{\cftdotsep}}
\renewcommand{\cftchapfont}{\normalsize \scshape}
\renewcommand\listfigurename{Listing of figures}
\renewcommand\listtablename{Listing of tables}

% Decrease the amount of space used by \chapter
\RequirePackage{titlesec}
\titleformat{\chapter}[display]
{\stratosB\Large}{\chaptertitlename\ \thechapter}{20pt}{\Huge}[\normalfont]
\titlespacing*{\chapter}{0pt}{-35pt}{30pt}

\titleformat{\section}%
   {\stratosB\Large} % format
   {\thesection} % label
   {1em} % sep
   {} % before
   [\normalfont] % after

\titleformat{\subsection}%
   {\stratosM\large} % format
   {\thesubsection} % label
   {1em} % sep
   {} % before
   [\normalfont] % after

\titleformat{\subsubsection}%
   {\stratosR} % format
   {\thesubsubsection} % label
   {1em} % sep
   {} % before
   [\normalfont] % after




\RequirePackage{fancyhdr}
\fancypagestyle{plain}{%
  \setlength{\headheight}{13.59999pt}
  \addtolength{\topmargin}{-1.59999pt}
  %uncomment to remove the bar from the top
  %\renewcommand{\headrulewidth}{0pt}
  %\renewcommand{\footrulewidth}{0pt}
  \fancyhead{} % clear everything
  \fancyfoot[C]{\thepage}
  \fancyhead[R]{\includegraphics[width=0.1\textwidth]{cover/tweag-logo.pdf}}
}

%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%
%%  Title Page  %%
%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%

%% Specifies the client for whom we're auditing
\let\@TWAClient\@empty
\newcommand{\TWASetClient}[1]{\gdef\@TWAClient{#1}}
\newcommand{\TWAClient}{\@TWAClient}

%% Optionally, specify the name of the product we're auditing
\let\@TWAProduct\@empty
\newcommand{\TWASetProduct}[1]{\gdef\@TWAProduct{#1}}
\newcommand{\TWAProduct}{\@TWAProduct}

\let\@subtitle\@empty
\newcommand{\subtitle}[1]{\gdef\@subtitle{#1}}

\let\@TWADate\@empty
\newcommand{\TWASetDate}[1]{\gdef\@TWADate{#1}}
\newcommand{\TWADate}{\@TWADate}

%% Returns the product name if that's set, otherwise returns the client
%% name; if none is set gives us an error.
\newcommand{\TWAProductOrClient}{
\ifx\@TWAProduct\empty
  \ifx\@TWAClient\empty
    \ClassError{twaudit}{client is not set}{Make sure to set the client and optionally, the product}
  \else
    \ClassWarning{twaudit}{You asked for TWAProductOrClient, but TWAProduct is not set}
    \@TWAClient
  \fi
\else
  \@TWAProduct
\fi
}

\renewcommand{\maketitle}{
%%%%%%%%%%%%%
%% Custom page numbering to hack duplicate-destinations
%% seen in: https://tex.stackexchange.com/questions/18924/pdftex-warning-ext4-destination-with-the-same-identifier-nam-epage-1-has
\pagenumbering{Alph}
%% \hypersetup{pageanchor=false}
%% Custom title page geometry
\newgeometry{left=0.17\paperwidth,right=0.17\paperwidth}
\thispagestyle{empty}
\begingroup
% \fontsize{9pt}{7pt}\selectfont
\begin{center}
%%%%%%%%%%%%%
%% Headings
  \vspace*{0.20\paperheight} %
  \includegraphics[width=0.5\textwidth]{cover/tweag-logo.pdf}
  \vspace*{0.02\paperheight} %

  \

  \begin{LARGE}
  {\stratosB \@title}
  \end{LARGE}

  \ifx\@subtitle\empty\else
  \vspace*{1em}
  \begin{large}
  {\stratosR \@subtitle}
  \end{large}
  \fi

  \

  \vspace*{0.1\paperheight} %
  {\stratosL \@author

   \
   \@TWADate
  }
\end{center}
\endgroup
%%%%%%%%%%%%
%% Restore our previous geometry
\restoregeometry
\pagenumbering{arabic}
\pagestyle{plain}
}

%% End of title page

%%%%%%%%%%%%%%%%%%%%%%
%% General Packages %%
%%%%%%%%%%%%%%%%%%%%%%

%% Indexing
% \usepackage{imakeidx}
% \makeindex[options=-s tex/latex/index_style.ist]
% \newcommand{\withindex}[1]{#1\index{#1}}

\usepackage{alltt}
\usepackage{microtype}
\usepackage{booktabs}
\usepackage{multirow}
\usepackage{subfig}

%% Refine reference format to include parenthesis
%% Taken from: https://tex.stackexchange.com/questions/75014/is-it-possible-to-make-a-reference-to-a-subfigure-to-appear-figure-2a-with-cle
\captionsetup[subfigure]{ subrefformat=simple %
                        , labelformat=simple %
                        , listofformat=subsimple}
\renewcommand\thesubfigure{(\textsc{\alph{subfigure}})}


%% Hacks for preventing orphan lines
%% https://tex.stackexchange.com/questions/4152/how-do-i-prevent-widow-orphan-lines
\clubpenalty=10000
\widowpenalty=10000
\displaywidowpenalty=10000

% hyperref MUST be loaded first. Check section 14.1 of cleveref manual.
\usepackage[pdfpagelabels,plainpages=false]{hyperref}
\usepackage{cleveref}

%% Recommented to give more professionally-looking tables.
\renewcommand{\arraystretch}{1.2}

%% number up to subsubsections
\setcounter{secnumdepth}{3}

%% Theorems and Definitions
\usepackage{amsthm}

\theoremstyle{definition}
\newtheorem{definition}{Definition}[section]

\theoremstyle{plain}
\newtheorem{lemma}{Lemma}[section]
\newtheorem{theorem}{Theorem}[section]

%% Paragraph formatting

%% \setlength{\parskip}{0.5em}
%% These values work; but we get VERY weird erros with other combinations
\linespread{1.05}
%% \setlength{\parskip}{1em}

\usepackage[numbers,square]{natbib}

\usepackage[shortlabels]{enumitem}
\setlist[enumerate]{label=\alph*)}

\ifTWA@isdraft
\usepackage{layouts}
\newcommand{\displaymeasurespage}{%
\newpage
\thispagestyle{empty}
Measures page (is here because of \texttt{draft} option)
\begin{center}
\begin{tabular}{rl}
  \texttt{\textbackslash{}textwitdh} & \printinunitsof{cm}\prntlen{\textwidth} \\
  \texttt{\textbackslash{}paperwidth} & \printinunitsof{cm}\prntlen{\paperwidth} \\
  \texttt{\textbackslash{}paperheigth} & \printinunitsof{cm}\prntlen{\paperheight} \\
\end{tabular}
\end{center}
\newpage}
\usepackage[displaymath,mathlines]{lineno}
\linenumbers
\else
\newcommand{\displaymeasurespage}{}
\fi
