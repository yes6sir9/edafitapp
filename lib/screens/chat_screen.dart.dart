import 'package:flutter/material.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final List<Map<String, dynamic>> recipes;
  final String goal;
  final double mealCalories;
  final double mealProtein;

  const ChatScreen({
    super.key,
    required this.recipes,
    required this.goal,
    required this.mealCalories,
    required this.mealProtein,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService chatService = ChatService();
  final TextEditingController controller = TextEditingController();

  List<Map<String, dynamic>> messages = [];
  List<Map<String, dynamic>> recommendedRecipes = [];

  Future<void> sendMessage() async {
    final text = controller.text;
    controller.clear();

    setState(() {
      messages.add({"text": text, "isUser": true});
    });

    final response = await chatService.processMessage(
      message: text,
      allRecipes: widget.recipes,
      goal: widget.goal,
      mealCalories: widget.mealCalories,
      mealProtein: widget.mealProtein,
    );

    setState(() {
      messages.add({"text": response["text"], "isUser": false});
      recommendedRecipes = response["recipes"];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: messages.map((m) {
              return ListTile(
                title: Text(m["text"]),
                tileColor: m["isUser"]
                    ? Colors.green[100]
                    : Colors.grey[200],
              );
            }).toList(),
          ),
        ),

        // 🥗 Рецепты
        if (recommendedRecipes.isNotEmpty)
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: recommendedRecipes.length,
              itemBuilder: (context, index) {
                final r = recommendedRecipes[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Text(r['title']),
                        Text("${r['calories']} kcal"),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        Row(
          children: [
            Expanded(
              child: TextField(controller: controller),
            ),
            IconButton(
              icon: Icon(Icons.send),
              onPressed: sendMessage,
            )
          ],
        )
      ],
    );
  }
}