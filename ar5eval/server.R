library(dplyr)
library(purrr)
library(ggplot2)
.theme <- theme(panel.grid.major=element_line(size = .5, color = "grey"),
                    plot.title=element_text(hjust=0),
                    axis.line=element_line(size=.7, color="black"),
                    axis.ticks.length=unit(0.35,"cm"),
                    legend.position="bottom",
                    text = element_text(size=14),
                    panel.spacing.x=unit(0.25,"cm"),
                    plot.margin=unit(c(0.5, 1, 0.5, 0.5),"cm"),
                    strip.text=element_text(size=14))

shinyServer(function(input, output, session) {
  
  source("tour.R", local=TRUE) # introjs tour
  
  observeEvent(input$staticmap, {
    showModal(modalDialog(
      title="AR5 GCM evalutation spatial domains",
      img(src='domain_map.png', align="center", style="width: 100%"),
      size="l", easyClose=TRUE, footer=NULL
      ))
  })
  
  dsub <- reactive({ 
    x <- filter(d, Domain %in% input$spdom & Stat %in% input$stat & 
                  Var %in% input$vars & Period %in% input$time) %>%
          group_by(Domain, Stat, Var) %>% filter(rank(Mean_Rank) <= input$n_gcms) %>% ungroup
    if(input$order=="mean") 
      x <- mutate(x, GCM=factor(GCM, levels=GCM[order(Mean_Rank)]))
    x
  })
  
  clrby <- reactive({ if(input$clrby=="") NULL else input$clrby })
  
  period <- reactive({ 
    if(input$time=="Annual") "mean annual" else month.name[match(input$time, month.abb)] 
  })
  
  output$rankPlot <- renderPlot({
    if(is.null(input$spdom) || is.null(input$stat) || is.null(input$vars)) return()
    pos <- if(!is.null(clrby())) position_dodge(width=0.75) else "identity"
    subtitle <- paste("based on", period(), "error metric")
    g <- ggplot(dsub(), 
      aes_string(x="GCM", y="Mean_Rank", ymin="Min_Rank", ymax="Max_Rank", colour=clrby())) +
      geom_point(position=pos) + geom_crossbar(width=0.5, position=pos)
    if(input$fctby!="") g <- g + facet_wrap(as.formula(paste0("~", input$fctby)), scales="free")
    g + .theme + 
      theme(axis.title.x=element_blank(), axis.text.x=element_blank(), axis.ticks.x=element_blank()) +
      labs(title="Spatial bootstrap GCM performance rankings", 
           subtitle=bquote(italic(.(subtitle))), 
           y="Bootstrap GCM rank range and mean")
  })
  
  output$top5Plot <- renderPlot({
    if(is.null(input$spdom) || is.null(input$stat) || is.null(input$vars)) return()
    pos <- if(!is.null(clrby())) position_dodge(width=0.75) else "identity"
    subtitle <- paste(period(), "spatial bootstrap of GCM ranking fifth or better")
    g <- ggplot(dsub(), 
                aes_string(x="GCM", y="PropTop5", fill=clrby())) +
      geom_bar(stat="identity", position=pos, colour="black", width=0.5)
    if(input$fctby!="") g <- g + facet_wrap(as.formula(paste0("~", input$fctby)), scales="free")
    g + .theme + theme(axis.text.x=element_text(angle=45, hjust=1, vjust=1)) +
      labs(title="Probability of GCM among top five performers", 
           subtitle=bquote(italic(.(subtitle))), 
           x="GCM", y="P(among top five performing GCMs)")
  })
  
  dom <- reactive(input$tabs)
  map(domains, ~callModule(spbootMod, paste0("sb", .x), .x, dom, .theme))
  map(domains, ~callModule(compositeMod, .x, .x, dom, .theme, info=gcm_inclusion))
})
