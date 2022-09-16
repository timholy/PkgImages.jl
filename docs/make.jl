using PkgImages
using Documenter

DocMeta.setdocmeta!(PkgImages, :DocTestSetup, :(using PkgImages); recursive=true)

makedocs(;
    modules=[PkgImages],
    authors="Tim Holy <tim.holy@gmail.com> and contributors",
    repo="https://github.com/timholy/PkgImages.jl/blob/{commit}{path}#{line}",
    sitename="PkgImages.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://timholy.github.io/PkgImages.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/timholy/PkgImages.jl",
    devbranch="main",
)
