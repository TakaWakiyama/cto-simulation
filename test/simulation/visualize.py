import pandas as pd
import matplotlib.pyplot as plt
import matplotlib
import os

matplotlib.rcParams['font.family'] = ['Hiragino Sans', 'sans-serif']
matplotlib.rcParams['axes.unicode_minus'] = False

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), 'output')
SUMMARY_CSV = os.path.join(OUTPUT_DIR, 'summary.csv')
TURN_CSV = os.path.join(OUTPUT_DIR, 'turn_snapshots.csv')

BOT_COLORS = {
    'Greedy': '#e74c3c',
    'Safe': '#2ecc71',
    'Growth': '#3498db',
    'SaaS': '#f39c12',
}
BOT_LABELS = {
    'Greedy': 'Greedy (貪欲)',
    'Safe': 'Safe (安全)',
    'Growth': 'Growth (成長投資)',
    'SaaS': 'SaaS (SaaS特化)',
}


def load_data():
    df = pd.read_csv(SUMMARY_CSV)
    turns = pd.read_csv(TURN_CSV)
    return df, turns


def fig1_profit_distribution(df):
    """利益分布 (箱ひげ図 + スウォーム)"""
    fig, axes = plt.subplots(1, 3, figsize=(18, 6))
    fig.suptitle('Bot別 経済指標の分布 (各200回)', fontsize=16, fontweight='bold')

    metrics = [
        ('total_revenue', '総売上 (万円)'),
        ('total_expense', '総支出 (万円)'),
        ('profit', '純利益 (万円)'),
    ]

    bots = list(BOT_COLORS.keys())

    for ax, (col, title) in zip(axes, metrics):
        data = [df[df['bot'] == b][col].values for b in bots]
        bp = ax.boxplot(data, labels=[BOT_LABELS[b] for b in bots],
                        patch_artist=True, widths=0.6,
                        medianprops=dict(color='black', linewidth=2))
        for patch, bot in zip(bp['boxes'], bots):
            patch.set_facecolor(BOT_COLORS[bot])
            patch.set_alpha(0.7)

        # 個別データ点をジッター付きでプロット
        for i, bot in enumerate(bots):
            vals = df[df['bot'] == bot][col].values
            jitter = (pd.Series(range(len(vals))).apply(
                lambda x: (x % 5 - 2) * 0.06)).values
            ax.scatter([i + 1 + j for j in jitter], vals,
                       alpha=0.15, s=8, color=BOT_COLORS[bot], zorder=3)

        ax.set_title(title, fontsize=13)
        ax.set_ylabel('万円')
        ax.axhline(y=0, color='gray', linestyle='--', alpha=0.5)
        ax.tick_params(axis='x', rotation=15)

    plt.tight_layout()
    path = os.path.join(OUTPUT_DIR, 'fig1_profit_distribution.png')
    fig.savefig(path, dpi=150, bbox_inches='tight')
    print(f'Saved {path}')
    plt.close()


def fig2_survival_and_completion(df):
    """生存率・案件完了数・最終資金"""
    fig, axes = plt.subplots(1, 3, figsize=(18, 6))
    fig.suptitle('Bot別 生存率・案件完了数・最終資金', fontsize=16, fontweight='bold')

    bots = list(BOT_COLORS.keys())

    # 生存率バー
    ax = axes[0]
    survival_rates = [df[df['bot'] == b]['survived'].mean() * 100 for b in bots]
    bars = ax.bar([BOT_LABELS[b] for b in bots], survival_rates,
                  color=[BOT_COLORS[b] for b in bots], alpha=0.8)
    for bar, rate in zip(bars, survival_rates):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1,
                f'{rate:.0f}%', ha='center', fontsize=12, fontweight='bold')
    ax.set_title('120ターン生存率', fontsize=13)
    ax.set_ylabel('%')
    ax.set_ylim(0, 110)
    ax.tick_params(axis='x', rotation=15)

    # 案件完了数
    ax = axes[1]
    data = [df[df['bot'] == b]['projects_completed'].values for b in bots]
    bp = ax.boxplot(data, labels=[BOT_LABELS[b] for b in bots],
                    patch_artist=True, widths=0.6,
                    medianprops=dict(color='black', linewidth=2))
    for patch, bot in zip(bp['boxes'], bots):
        patch.set_facecolor(BOT_COLORS[bot])
        patch.set_alpha(0.7)
    ax.set_title('案件完了数', fontsize=13)
    ax.set_ylabel('件')
    ax.tick_params(axis='x', rotation=15)

    # 最終資金
    ax = axes[2]
    data = [df[df['bot'] == b]['final_money'].values for b in bots]
    bp = ax.boxplot(data, labels=[BOT_LABELS[b] for b in bots],
                    patch_artist=True, widths=0.6,
                    medianprops=dict(color='black', linewidth=2))
    for patch, bot in zip(bp['boxes'], bots):
        patch.set_facecolor(BOT_COLORS[bot])
        patch.set_alpha(0.7)
    ax.set_title('最終資金', fontsize=13)
    ax.set_ylabel('万円')
    ax.axhline(y=0, color='gray', linestyle='--', alpha=0.5)
    ax.tick_params(axis='x', rotation=15)

    plt.tight_layout()
    path = os.path.join(OUTPUT_DIR, 'fig2_survival_completion.png')
    fig.savefig(path, dpi=150, bbox_inches='tight')
    print(f'Saved {path}')
    plt.close()


def fig3_timeline(turns):
    """ターン経過での資金推移（中央値 + 25-75%バンド）"""
    fig, axes = plt.subplots(2, 2, figsize=(16, 12))
    fig.suptitle('ターン経過での経済推移 (中央値 + 25-75%帯)', fontsize=16, fontweight='bold')

    metrics = [
        ('money', '手持ち資金 (万円)'),
        ('revenue', '累計売上 (万円)'),
        ('expense', '累計支出 (万円)'),
        ('trust', '信頼度'),
    ]

    bots = list(BOT_COLORS.keys())

    for ax, (col, title) in zip(axes.flat, metrics):
        for bot in bots:
            bt = turns[turns['bot'] == bot]
            grouped = bt.groupby('turn')[col]
            median = grouped.median()
            q25 = grouped.quantile(0.25)
            q75 = grouped.quantile(0.75)

            ax.plot(median.index, median.values,
                    color=BOT_COLORS[bot], label=BOT_LABELS[bot], linewidth=2)
            ax.fill_between(median.index, q25.values, q75.values,
                            color=BOT_COLORS[bot], alpha=0.15)

        ax.set_title(title, fontsize=13)
        ax.set_xlabel('ターン')
        ax.legend(fontsize=9)
        ax.grid(True, alpha=0.3)
        if col == 'money':
            ax.axhline(y=0, color='gray', linestyle='--', alpha=0.5)

    plt.tight_layout()
    path = os.path.join(OUTPUT_DIR, 'fig3_timeline.png')
    fig.savefig(path, dpi=150, bbox_inches='tight')
    print(f'Saved {path}')
    plt.close()


def fig4_profit_histogram(df):
    """利益のヒストグラム（重ね合わせ）"""
    fig, ax = plt.subplots(figsize=(12, 6))
    fig.suptitle('純利益の分布（ヒストグラム）', fontsize=16, fontweight='bold')

    bots = list(BOT_COLORS.keys())

    for bot in bots:
        vals = df[df['bot'] == bot]['profit'].values
        ax.hist(vals, bins=30, alpha=0.5, color=BOT_COLORS[bot],
                label=f'{BOT_LABELS[bot]} (中央値: {int(pd.Series(vals).median())}万)', edgecolor='white')

    ax.axvline(x=0, color='black', linestyle='--', linewidth=1.5, label='損益分岐点')
    ax.set_xlabel('純利益 (万円)')
    ax.set_ylabel('頻度')
    ax.legend(fontsize=10)
    ax.grid(True, alpha=0.3, axis='y')

    plt.tight_layout()
    path = os.path.join(OUTPUT_DIR, 'fig4_profit_histogram.png')
    fig.savefig(path, dpi=150, bbox_inches='tight')
    print(f'Saved {path}')
    plt.close()


def fig5_revenue_vs_expense_scatter(df):
    """売上 vs 支出の散布図"""
    fig, ax = plt.subplots(figsize=(10, 10))
    fig.suptitle('総売上 vs 総支出', fontsize=16, fontweight='bold')

    bots = list(BOT_COLORS.keys())
    max_val = 0

    for bot in bots:
        bd = df[df['bot'] == bot]
        ax.scatter(bd['total_expense'], bd['total_revenue'],
                   alpha=0.4, s=30, color=BOT_COLORS[bot],
                   label=BOT_LABELS[bot], edgecolors='white', linewidth=0.3)
        max_val = max(max_val, bd['total_revenue'].max(), bd['total_expense'].max())

    # 損益分岐線
    ax.plot([0, max_val * 1.1], [0, max_val * 1.1],
            'k--', alpha=0.5, label='損益分岐線')

    ax.set_xlabel('総支出 (万円)')
    ax.set_ylabel('総売上 (万円)')
    ax.legend(fontsize=10)
    ax.grid(True, alpha=0.3)
    ax.set_aspect('equal')

    plt.tight_layout()
    path = os.path.join(OUTPUT_DIR, 'fig5_revenue_vs_expense.png')
    fig.savefig(path, dpi=150, bbox_inches='tight')
    print(f'Saved {path}')
    plt.close()


def print_percentile_table(df):
    """パーセンタイルテーブルをコンソール出力"""
    print('\n' + '=' * 80)
    print('  利益パーセンタイル分布 (万円)')
    print('=' * 80)
    print(f'  {"Bot":<20} {"10%":>8} {"25%":>8} {"50%":>8} {"75%":>8} {"90%":>8} {"平均":>8}')
    print('-' * 80)
    for bot in ['Greedy', 'Safe', 'Growth', 'SaaS']:
        vals = df[df['bot'] == bot]['profit']
        print(f'  {BOT_LABELS[bot]:<20}'
              f' {vals.quantile(0.10):>8.0f}'
              f' {vals.quantile(0.25):>8.0f}'
              f' {vals.quantile(0.50):>8.0f}'
              f' {vals.quantile(0.75):>8.0f}'
              f' {vals.quantile(0.90):>8.0f}'
              f' {vals.mean():>8.0f}')
    print('=' * 80)


if __name__ == '__main__':
    df, turns = load_data()
    print(f'Loaded {len(df)} run summaries, {len(turns)} turn snapshots')

    fig1_profit_distribution(df)
    fig2_survival_and_completion(df)
    fig3_timeline(turns)
    fig4_profit_histogram(df)
    fig5_revenue_vs_expense_scatter(df)
    print_percentile_table(df)

    print(f'\nAll charts saved to {OUTPUT_DIR}/')
