class QuizQuestion {
  final String question;
  final List<String> options;
  final int answerIndex;
  final String explanation;
  int? userSelectedIndex;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.explanation,
    this.userSelectedIndex,
  });

  bool get isAnswered => userSelectedIndex != null;
  bool get isCorrect => userSelectedIndex == answerIndex;

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'answerIndex': answerIndex,
        'explanation': explanation,
        'userSelectedIndex': userSelectedIndex,
      };

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] as String? ?? 'Question',
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['Option A', 'Option B', 'Option C', 'Option D'],
      answerIndex: json['answerIndex'] as int? ?? 0,
      explanation: json['explanation'] as String? ?? 'Explanation',
      userSelectedIndex: json['userSelectedIndex'] as int?,
    );
  }
}

class QuizModel {
  final String id;
  final String title;
  final String sourceDescription;
  final List<QuizQuestion> questions;
  final DateTime createdAt;

  QuizModel({
    required this.id,
    required this.title,
    required this.sourceDescription,
    required this.questions,
    required this.createdAt,
  });

  int get score => questions.where((q) => q.isCorrect).length;
  int get totalQuestions => questions.length;
  double get percentage => totalQuestions > 0 ? (score / totalQuestions) * 100 : 0.0;
  bool get isCompleted => questions.every((q) => q.isAnswered);
}
