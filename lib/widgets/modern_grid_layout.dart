import 'package:flutter/material.dart';

class ModernGridLayout extends StatelessWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  const ModernGridLayout({
    Key? key,
    required this.children,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 16,
    this.crossAxisSpacing = 16,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = List.generate(crossAxisCount, (index) => <Widget>[]);
        
        for (int i = 0; i < children.length; i++) {
          columns[i % crossAxisCount].add(children[i]);
          if (i % crossAxisCount != crossAxisCount - 1 && i != children.length - 1) {
            columns[i % crossAxisCount].add(SizedBox(height: mainAxisSpacing));
          }
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: columns.asMap().entries.map((entry) {
            final index = entry.key;
            final columnChildren = entry.value;
            
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < crossAxisCount - 1 ? crossAxisSpacing : 0,
                ),
                child: Column(
                  children: columnChildren,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// Widget para cards com tamanhos diferentes
class FlexibleCard extends StatelessWidget {
  final String texto;
  final VoidCallback onTap;
  final IconData? icone;
  final String? customIcon;
  final double? height;
  final bool isLarge;

  const FlexibleCard({
    Key? key,
    required this.texto,
    required this.onTap,
    this.icone,
    this.customIcon,
    this.height,
    this.isLarge = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: const Color(0xFF049F56).withOpacity(0.2),
        highlightColor: const Color(0xFF049F56).withOpacity(0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: height ?? (isLarge ? 180 : 140),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            // Gradiente variado baseado no tamanho
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isLarge 
                ? [
                    const Color(0xFF049F56).withOpacity(0.3),
                    const Color(0xFF045D3A).withOpacity(0.2),
                    Colors.white.withOpacity(0.1),
                  ]
                : [
                    Colors.white.withOpacity(0.25),
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(isLarge ? 0.4 : 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isLarge ? 0.15 : 0.1),
                blurRadius: isLarge ? 25 : 20,
                spreadRadius: 0,
                offset: Offset(0, isLarge ? 12 : 8),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.6),
                blurRadius: 10,
                spreadRadius: -5,
                offset: const Offset(0, -2),
              ),
              if (isLarge)
                BoxShadow(
                  color: const Color(0xFF049F56).withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: -10,
                  offset: const Offset(0, 15),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Container do ícone com tamanho dinâmico
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.all(isLarge ? 20 : 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF049F56),
                      const Color(0xFF045D3A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(isLarge ? 24 : 20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF049F56).withOpacity(0.3),
                      blurRadius: isLarge ? 20 : 15,
                      spreadRadius: 0,
                      offset: Offset(0, isLarge ? 8 : 6),
                    ),
                  ],
                ),
                child: customIcon != null
                    ? Image.asset(
                        customIcon!, 
                        width: isLarge ? 40 : 32, 
                        height: isLarge ? 40 : 32,
                        color: Colors.white,
                      )
                    : Icon(
                        icone ?? Icons.help_outline, 
                        size: isLarge ? 40 : 32, 
                        color: Colors.white,
                      ),
              ),
              SizedBox(height: isLarge ? 20 : 16),
              
              // Texto com tamanho responsivo
              Text(
                texto,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isLarge ? 17 : 15,
                  fontWeight: FontWeight.w700,
                  color: isLarge ? Colors.white : const Color(0xFF045D3A),
                  height: 1.3,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
