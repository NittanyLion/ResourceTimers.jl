using ResourceTimers
using Documenter

DocMeta.setdocmeta!(ResourceTimers, :DocTestSetup, :(using ResourceTimers); recursive=true)

makedocs(;
    modules=[ResourceTimers],
    authors="Joris Pinkse <pinkse@gmail.com> and contributors",
    sitename="ResourceTimers.jl",
    format=Documenter.HTML(;
        canonical="https://NittanyLion.github.io/ResourceTimers.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/NittanyLion/ResourceTimers.jl",
    devbranch="main",
)
